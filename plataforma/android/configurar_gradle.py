"""Ajusta el build.gradle que genera `flutter create` para usar youtubedl-android.

Lo ejecuta el workflow: python3 plataforma/android/configurar_gradle.py android/app

- minSdk 24 (lo exige youtubedl-android).
- useLegacyPackaging: los binarios de Python, ffmpeg y QuickJS viajan como .so y
  Android debe extraerlos al instalar para poder ejecutarlos.
- Reglas de ProGuard para que R8 no borre clases de la librería.
- Dependencias de la librería y de ffmpeg (unir video+audio y convertir a MP3).
"""
import os
import re
import sys

YTDL_VERSION = "0.18.1"
LIBS = [
    "io.github.junkfood02.youtubedl-android:library:" + YTDL_VERSION,
    "io.github.junkfood02.youtubedl-android:ffmpeg:" + YTDL_VERSION,
]

KTS_EXTRA = """

// --- Agregado por plataforma/android/configurar_gradle.py ---
android {
    packaging {
        jniLibs {
            useLegacyPackaging = true
        }
    }
    buildTypes {
        getByName("release") {
            proguardFiles("proguard-rules.pro")
        }
    }
}

dependencies {
%s
}
""" % "\n".join('    implementation("%s")' % lib for lib in LIBS)

GROOVY_EXTRA = """

// --- Agregado por plataforma/android/configurar_gradle.py ---
android {
    packagingOptions {
        jniLibs {
            useLegacyPackaging true
        }
    }
    buildTypes {
        release {
            proguardFiles 'proguard-rules.pro'
        }
    }
}

dependencies {
%s
}
""" % "\n".join("    implementation '%s'" % lib for lib in LIBS)


def main(app_dir):
    kts = os.path.join(app_dir, "build.gradle.kts")
    groovy = os.path.join(app_dir, "build.gradle")
    if os.path.exists(kts):
        path, is_kts = kts, True
    elif os.path.exists(groovy):
        path, is_kts = groovy, False
    else:
        sys.exit("No se encontró build.gradle(.kts) en " + app_dir)

    with open(path, encoding="utf-8") as f:
        text = f.read()

    min_sdk_line = "minSdk = 24" if is_kts else "minSdkVersion 24"
    text, count = re.subn(
        r"^(\s*)minSdk(?:Version)?\b.*$",
        lambda m: m.group(1) + min_sdk_line,
        text,
        flags=re.MULTILINE,
    )
    if count == 0:
        sys.exit("No se encontró la línea minSdk en " + path)

    text = text.rstrip() + "\n" + (KTS_EXTRA if is_kts else GROOVY_EXTRA)

    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    print("Configurado:", path)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "android/app")
