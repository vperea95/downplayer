"""Firma fija del APK con la llave de Vixago.

Lo ejecuta el workflow: python3 plataforma/android/configurar_firma.py android/app

Solo actúa si existe la variable SIGNING_KEYSTORE_PATH (el workflow la crea con el
secreto SIGNING_KEYSTORE_BASE64). Agrega al build.gradle.kts que genera
`flutter create` una configuración de firma "vixago" y la usa en release.
La contraseña llega en SIGNING_KEYSTORE_PASSWORD, nunca se escribe en el repositorio.

Con firma fija, cada APK nuevo se instala encima del anterior sin borrar los datos.
"""
import os
import sys

SIGNING_BLOCK = """
    // --- Firma fija (agregado por plataforma/android/configurar_firma.py) ---
    signingConfigs {
        create("vixago") {
            storeFile = file(System.getenv("SIGNING_KEYSTORE_PATH"))
            storePassword = System.getenv("SIGNING_KEYSTORE_PASSWORD")
            keyAlias = "vixago"
            keyPassword = System.getenv("SIGNING_KEYSTORE_PASSWORD")
            storeType = "pkcs12"
        }
    }

"""

DEBUG_LINE = 'signingConfig = signingConfigs.getByName("debug")'
RELEASE_LINE = 'signingConfig = signingConfigs.getByName("vixago")'


def main(app_dir):
    if not os.environ.get("SIGNING_KEYSTORE_PATH"):
        print("Sin SIGNING_KEYSTORE_PATH: se deja la firma de prueba (debug).")
        return

    path = os.path.join(app_dir, "build.gradle.kts")
    if not os.path.exists(path):
        sys.exit("No se encontró " + path)
    with open(path, encoding="utf-8") as f:
        text = f.read()

    if text.count(DEBUG_LINE) != 1:
        sys.exit("No se encontró una sola línea '%s' en %s" % (DEBUG_LINE, path))
    marker = "\n    buildTypes {"
    if text.count(marker) != 1:
        sys.exit("No se encontró el bloque buildTypes en " + path)

    text = text.replace(marker, "\n" + SIGNING_BLOCK.rstrip("\n") + "\n" + marker, 1)
    text = text.replace(DEBUG_LINE, RELEASE_LINE)

    with open(path, "w", encoding="utf-8") as f:
        f.write(text)
    print("Firma fija configurada en", path)


if __name__ == "__main__":
    main(sys.argv[1] if len(sys.argv) > 1 else "android/app")
