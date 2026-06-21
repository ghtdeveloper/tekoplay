# Flutter
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.embedding.**

# Firebase
-keep class com.google.firebase.** { *; }
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.firebase.**
-dontwarn com.google.android.gms.**

# Facebook Auth
-keep class com.facebook.** { *; }
-dontwarn com.facebook.**

# Google Sign-In
-keep class com.google.android.gms.auth.** { *; }

# Stockfish (native library — no tocar)
-keep class com.tekoplay.flutter_stockfish_plugin.** { *; }

# Google Ads
-keep class com.google.android.gms.ads.** { *; }

# Pay / Google Pay
-keep class com.google.android.gms.wallet.** { *; }

# Play Core (referenciado por FlutterPlayStoreSplitApplication — requerido por R8)
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }
-dontwarn com.google.android.play.core.**

# Evitar que R8 elimine clases referenciadas por reflexión
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes Exceptions
