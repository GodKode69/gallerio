# Flutter MethodChannel
-keep class com.arqora.gallerio.MainActivity { *; }

# Play Core split install (not used, but referenced by Flutter engine)
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**

# photo_manager
-keep class com.fluttercain.plugins.photomanager.** { *; }

# permission_handler
-keep class com.baseflow.permissionhandler.** { *; }

# file_picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# share_plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# flutter_secure_storage
-keep class com.it_nomads.fluttersecurestorage.** { *; }

# local_auth
-keep class io.flutter.plugins.localauth.** { *; }
