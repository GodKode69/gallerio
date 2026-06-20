package com.arqora.gallerio

import android.app.WallpaperManager
import android.content.ClipData
import android.content.ClipboardManager
import android.content.ContentValues
import android.content.ContentUris
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.ByteArrayOutputStream
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.arqora.gallerio/open_file"

    private fun isPathInAppSandbox(filePath: String): Boolean {
        val canonicalPath = File(filePath).canonicalPath
        val dirs = listOfNotNull(
            applicationInfo.dataDir?.let { File(it).canonicalPath },
            cacheDir.canonicalPath,
            externalCacheDir?.parentFile?.canonicalPath,
        )
        return dirs.any { canonicalPath.startsWith(it) }
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "openVideo" -> {
                    val filePath = call.argument<String>("filePath")
                    val mimeType = call.argument<String>("mimeType") ?: "video/*"

                    if (filePath == null) {
                        result.error("INVALID_PATH", "File path is null", null)
                    } else if (!isPathInAppSandbox(filePath)) {
                        result.error("ACCESS_DENIED", "Access denied", null)
                    } else {
                        try {
                            val file = File(filePath)
                            if (file.exists()) {
                                val uri = FileProvider.getUriForFile(
                                    this,
                                    "${packageName}.fileprovider",
                                    file
                                )

                                val intent = Intent(Intent.ACTION_VIEW).apply {
                                    setDataAndType(uri, mimeType)
                                    addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                                }

                                startActivity(intent)
                                result.success(true)
                            } else {
                                result.error("FILE_NOT_FOUND", "File not found", null)
                            }
                        } catch (_: Exception) {
                            result.error("ERROR", "Could not open file", null)
                        }
                    }
                }
                "setWallpaper" -> {
                    val filePath = call.argument<String>("filePath")
                    val target = call.argument<String>("target") ?: "both"
                    if (filePath == null) {
                        result.error("INVALID_PATH", "File path is null", null)
                    } else if (!isPathInAppSandbox(filePath)) {
                        result.error("ACCESS_DENIED", "Access denied", null)
                    } else {
                        try {
                            val file = File(filePath)
                            if (file.exists()) {
                                val wallpaperManager = WallpaperManager.getInstance(this)
                                val inputStream = file.inputStream()
                                val bitmap = BitmapFactory.decodeStream(inputStream)
                                inputStream.close()
                                if (bitmap == null) {
                                    result.error("DECODE_FAILED", "Could not decode image", null)
                                    return@setMethodCallHandler
                                }
                                val flags = when (target) {
                                    "lock" -> WallpaperManager.FLAG_LOCK
                                    "home" -> WallpaperManager.FLAG_SYSTEM
                                    else -> WallpaperManager.FLAG_SYSTEM or WallpaperManager.FLAG_LOCK
                                }
                                wallpaperManager.setBitmap(bitmap, null, true, flags)
                                bitmap.recycle()
                                result.success(true)
                            } else {
                                result.error("FILE_NOT_FOUND", "File not found", null)
                            }
                        } catch (e: Exception) {
                            result.error("ERROR", "Could not set wallpaper: ${e.message}", null)
                        }
                    }
                }
                "renameAsset" -> {
                    val assetId = call.argument<String>("assetId")
                    val newName = call.argument<String>("newName")
                    if (assetId == null || newName == null) {
                        result.error("INVALID_ARGS", "assetId and newName are required", null)
                    } else {
                        try {
                            val id = assetId.toLongOrNull()
                            if (id == null) {
                                result.error("INVALID_ARGS", "assetId must be a valid number", null)
                                return@setMethodCallHandler
                            }

                            val imagesCollection = MediaStore.Images.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)
                            val videosCollection = MediaStore.Video.Media.getContentUri(MediaStore.VOLUME_EXTERNAL_PRIMARY)

                            var itemUri = ContentUris.withAppendedId(imagesCollection, id)
                            var updated = contentResolver.update(
                                itemUri,
                                ContentValues().apply {
                                    put(MediaStore.MediaColumns.DISPLAY_NAME, newName)
                                },
                                null,
                                null
                            )

                            if (updated == 0) {
                                itemUri = ContentUris.withAppendedId(videosCollection, id)
                                updated = contentResolver.update(
                                    itemUri,
                                    ContentValues().apply {
                                        put(MediaStore.MediaColumns.DISPLAY_NAME, newName)
                                    },
                                    null,
                                    null
                                )
                            }

                            if (updated > 0) {
                                result.success(true)
                            } else {
                                result.error("RENAME_FAILED", "Could not find asset in MediaStore", null)
                            }
                        } catch (e: Exception) {
                            result.error("ERROR", "Rename failed: ${e.message}", null)
                        }
                    }
                }
                "copyImageToClipboard" -> {
                    val filePath = call.argument<String>("filePath")
                    if (filePath == null) {
                        result.error("INVALID_PATH", "File path is null", null)
                    } else {
                        try {
                            val file = File(filePath)
                            if (!file.exists()) {
                                result.error("FILE_NOT_FOUND", "File not found", null)
                                return@setMethodCallHandler
                            }
                            val bitmap = BitmapFactory.decodeFile(filePath)
                            if (bitmap == null) {
                                result.error("DECODE_FAILED", "Could not decode image", null)
                                return@setMethodCallHandler
                            }
                            val stream = ByteArrayOutputStream()
                            bitmap.compress(Bitmap.CompressFormat.PNG, 100, stream)
                            bitmap.recycle()
                            val bytes = stream.toByteArray()

                            val savedFile = File(cacheDir, "clipboard_${System.currentTimeMillis()}.png")
                            savedFile.writeBytes(bytes)

                            val uri = FileProvider.getUriForFile(
                                this,
                                "${packageName}.fileprovider",
                                savedFile
                            )

                            val clipboard = getSystemService(CLIPBOARD_SERVICE) as ClipboardManager
                            val clip = ClipData.newUri(contentResolver, "Image", uri)
                            clipboard.setPrimaryClip(clip)
                            result.success(mapOf("sdkInt" to Build.VERSION.SDK_INT))
                        } catch (e: Exception) {
                            result.error("ERROR", "Clipboard copy failed: ${e.message}", null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
