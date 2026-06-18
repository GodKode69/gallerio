package com.arqora.gallerio

import android.app.WallpaperManager
import android.content.Intent
import android.net.Uri
import android.os.Build
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterFragmentActivity() {
    private val CHANNEL = "com.arqora.gallerio/open_file"

    private fun isPathInAppSandbox(filePath: String): Boolean {
        val appDir = applicationInfo.dataDir ?: return false
        val canonicalPath = File(filePath).canonicalPath
        return canonicalPath.startsWith(appDir)
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
                                wallpaperManager.setStream(inputStream)
                                inputStream.close()
                                result.success(true)
                            } else {
                                result.error("FILE_NOT_FOUND", "File not found", null)
                            }
                        } catch (_: Exception) {
                            result.error("ERROR", "Could not set wallpaper", null)
                        }
                    }
                }
                else -> result.notImplemented()
            }
        }
    }
}
