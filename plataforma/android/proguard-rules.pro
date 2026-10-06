# Reglas para youtubedl-android (yt-dlp). El workflow copia este archivo a
# android/app/proguard-rules.pro. Sin ellas, R8 puede borrar clases que la
# librería usa por reflexión (Jackson) y la compilación o la app fallan.
-keep class com.yausername.** { *; }
-keep class com.fasterxml.jackson.** { *; }
-keep class org.apache.commons.compress.** { *; }
-keep class org.apache.commons.io.** { *; }

-dontwarn com.fasterxml.jackson.**
-dontwarn org.apache.commons.**
-dontwarn java.beans.**
-dontwarn javax.**
-dontwarn org.tukaani.xz.**
-dontwarn org.brotli.**
-dontwarn com.github.luben.zstd.**
-dontwarn org.objectweb.asm.**
-dontwarn org.w3c.dom.bootstrap.DOMImplementationRegistry
-ignorewarnings
