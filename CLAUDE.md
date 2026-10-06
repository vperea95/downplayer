# DownPlayer — contexto del proyecto

App móvil en Flutter para descargar videos y audio (MP3) de TikTok, Facebook, Instagram y YouTube, sin publicidad. Inspirada en AhaTik. Solo Android (iOS no aplica: yt-dlp no puede correr dentro de una app de iOS).

Se construyó con la misma forma de trabajo que Radio Colombia (`C:\Users\ANDRES\Downloads\radio_colombia\radio_colombia`).

## Cómo trabajar con el usuario

- Responder siempre en español.
- El usuario trabaja en Windows, con `cmd`, en la carpeta `C:\Users\ANDRES\Documents\proyectos de apps\descargador de videos tiktok\DownPlayerTiktok`.
- **No tiene Flutter, Java ni Android SDK instalados localmente.** El APK se compila en GitHub Actions al hacer push a `main`. No proponer `flutter run` local salvo que el usuario decida instalar Flutter.
- Cuando haya que hacer pasos manuales (git, GitHub, instalar en el celular), darlos **uno a la vez** y en lenguaje simple.
- Para publicar cambios:
  ```bash
  git add .
  git commit -m "mensaje"
  git push
  ```
- Las advertencias `LF will be replaced by CRLF` al hacer `git add` son normales.

## Cómo se compila (importante)

El repositorio **no contiene** las carpetas `android/` ni `ios/`. El workflow `.github/workflows/compilar-apk.yml` hace esto en cada push:

1. Instala Java 17 y Flutter estable.
2. `flutter create --org com.downplayer --project-name downplayer --platforms=android .` genera `android/` (no toca `lib/` ni `pubspec.yaml`) y borra `test/`.
3. Copia `plataforma/android/AndroidManifest.xml` y `plataforma/android/proguard-rules.pro` (a `android/app/`).
4. Toma la primera línea (`package ...`) del `MainActivity.kt` generado y le pega el resto de `plataforma/android/MainActivity.kt`. **La primera línea de `plataforma/android/MainActivity.kt` debe ser siempre la línea `package`.**
5. `python3 plataforma/android/configurar_gradle.py android/app` modifica el `build.gradle.kts` (o `.gradle`) generado: `minSdk = 24`, `packaging.jniLibs.useLegacyPackaging = true`, reglas de ProGuard y las dependencias `io.github.junkfood02.youtubedl-android:library` y `:ffmpeg` (versión en `YTDL_VERSION`). Falla a propósito si no encuentra la línea `minSdk`.
6. `flutter pub get` (si falla, `flutter pub upgrade --major-versions`).
7. `dart run flutter_launcher_icons` y `dart run flutter_native_splash:create` generan el ícono y la pantalla de arranque (configurados al final de `pubspec.yaml`).
8. `flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64` y sube ambos APK en el artifact `downplayer-apk`. **El que sirve para casi todos los celulares es `app-arm64-v8a-release.apk`**; `armeabi-v7a` es para celulares viejos de 32 bits.

Notas:
- Cualquier cambio nativo de Android va en `plataforma/android/` y, si hace falta, en el workflow o en `configurar_gradle.py`.
- El APK se firma con la llave debug que se genera en cada ejecución, que cambia cada vez. Por eso **hay que desinstalar la versión anterior antes de instalar una nueva** (se pierde el historial de la app; los archivos descargados siguen en la galería).
- GitHub Actions a veces se queda en "Waiting for a runner". Si pasan más de 15 minutos: Cancel workflow y luego Re-run all jobs.

## Stack

- Flutter (SDK `^3.6.0`, Material 3, tema claro y oscuro según el sistema).
- **Motor de descarga: yt-dlp dentro del APK** con [youtubedl-android](https://github.com/yausername/youtubedl-android) 0.18.1, que trae Python, yt-dlp, ffmpeg (unir video+audio y convertir a MP3) y QuickJS (YouTube lo exige para sus retos de JavaScript). Por eso el APK pesa unos 70-100 MB. Se eligió en lugar de un motor ligero en Dart porque permite YouTube en Full HD, MP3 real, mejor soporte de Instagram y Facebook, y actualizar yt-dlp sin recompilar.
- `http`: solo para guardar miniaturas.
- `shared_preferences`: historial y cuentas conectadas.
- `path_provider`: carpeta de miniaturas.
- `video_player`: reproductor interno (abre los `content://` de la galería con `VideoPlayerController.contentUri`).
- `webview_flutter`: inicio de sesión opcional en Instagram y Facebook.
- `flutter_launcher_icons` y `flutter_native_splash` (dev): ícono y pantalla de arranque, generados en el workflow.
- Estado con `ChangeNotifier` + `ListenableBuilder` (sin provider ni riverpod). Las dependencias se pasan por constructor desde `main.dart`.

## Estructura

```
lib/
  main.dart                        Crea Engine, HistoryService, AccountsService y DownloadManager; engine.init() después de runApp
  theme.dart                       AppColors (rosa de marca #FE2C55), AppTitle ("Down" + "Player") y AppLogo (assets/icon/logo.png)
  models/social_network.dart       enum SocialNetwork: reconoce enlaces, colores, login, isCollectionUrl()
  models/media_info.dart           MediaInfo y BatchEntry desde el JSON de yt-dlp
  models/download.dart             DownloadOption (-> argumentos de yt-dlp), DownloadTask, HistoryEntry
  services/engine.dart             MethodChannel 'downplayer/engine'; friendlyError() traduce errores de yt-dlp
  services/download_manager.dart   Cola (2 a la vez), progreso, guardar en galería, pasar al historial
  services/history_service.dart    Historial en SharedPreferences y miniaturas locales
  services/accounts_service.dart   Cuentas conectadas (Instagram/Facebook)
  services/preferences_service.dart  Calidad preferida (0 = mejor, -1 = audio, 720 = hasta 720p)
  screens/home_screen.dart         Menú de 4 redes, menú lateral, barra Inicio/Historial, "Compartir -> DownPlayer"
  screens/download_screen.dart     Pegar enlace, tarjeta del video, Full HD / audio / lotes
  screens/batch_screen.dart        Cuadrícula de un perfil/canal/lista para descargar varios
  screens/history_screen.dart      En curso + descargados (filtros, compartir, abrir con, borrar)
  screens/player_screen.dart       Reproductor de video y audio
  screens/login_screen.dart        WebView para iniciar sesión
  widgets/                         network_logo, thumbnail, task_tile, quality_sheet
  utils/format_utils.dart          formatCount (2.97M), formatDuration, formatDate, extractUrl
assets/icon/                       app_icon.png (redondeado, 512), logo.png (256, dentro de la app),
                                   foreground.png (solo el dibujo, ~60% del lienzo) y background.png (degradado azul oscuro)
plataforma/android/                AndroidManifest.xml, MainActivity.kt, proguard-rules.pro, configurar_gradle.py
```

## Decisiones técnicas

**Motor (MainActivity.kt).** `MainActivity` hereda de `FlutterActivity`. El objeto `Engine` llama a `YoutubeDL.getInstance()`: `ensureInit()` (descomprime Python y ffmpeg la primera vez), `getInfo()` (`-J`, con `--flat-playlist --playlist-end 60` para lotes), `download()` y `update()` (canal STABLE). Todo corre en un `Executors.newCachedThreadPool()` y responde en el hilo principal. Se llama a `execute(request, id, false, callback)` con los 4 argumentos porque la librería tiene dos versiones de `execute` y con menos argumentos Kotlin puede quejarse de ambigüedad. El progreso llega a Dart con `channel.invokeMethod("progress", {id, progress 0-100, eta, line})`.

**Descarga.** Cada descarga va a `cacheDir/descargas/<id>/` con plantilla `%(title).60B [%(id)s].%(ext)s` y `--windows-filenames`. Luego `saveToGallery` la copia con MediaStore a `Movies/DownPlayer` (video) o `Music/DownPlayer` (audio) y borra la carpeta temporal. En Android 9 o anterior pide `WRITE_EXTERNAL_STORAGE` y usa `MediaScannerConnection`.

**Formatos (`DownloadOption.toArgs`).**
- Video: `-f "bv*[vcodec!^=av01]+ba/b/bv*+ba" -S "res[:altura],vcodec:h264,acodec:aac" --merge-output-format mp4`. Se evita AV1 porque muchos celulares no lo abren.
- Audio: `-f ba/b -x --audio-format mp3 --audio-quality 0`.
- TikTok: yt-dlp ya prefiere el formato sin marca de agua.

**Calidades.** `MediaInfo.qualities` agrupa los formatos por el lado corto del video (1080x1920 es "1080p"), igual que el campo `res` de yt-dlp, y omite AV1. Por cada calidad elige el formato H.264 de más bitrate y estima el peso (`filesize`, `filesize_approx` o `tbr x duración`, más el mejor audio si el video viene sin sonido). `showQualitySheet` muestra todas las calidades con su peso y sus fps, marca "Tu preferida" (la más cercana por debajo a la última elección) y la guarda en `PreferencesService`. El botón grande "Elegir calidad y descargar" abre esa hoja. En lotes hay un desplegable: Mejor, hasta 1080, 720, 480 o 360, o solo audio.

**Ícono.** El original (1254 px con fondo blanco) se recortó con Pillow. En Android 8+ es un ícono adaptable: `foreground.png` (dibujo con fondo transparente, porque el azul casi negro original se volvió transparente por brillo) sobre `background.png` (degradado de #081A4E a #00020E). La pantalla de arranque usa el color #030B24. Dentro de la app aparece en la barra superior, el menú lateral, "Acerca de" y el historial vacío.

**Lotes.** TikTok: `https://www.tiktok.com/@usuario`. YouTube: `channel_url + /videos`, o el enlace de lista/canal pegado directamente (`isCollectionUrl`). Facebook e Instagram no tienen lotes.

**Instagram y Facebook.** Muchos videos piden sesión. `LoginScreen` abre la página oficial en un WebView. `saveCookies` copia las cookies del `CookieManager` de Android a `filesDir/cookies/<dominio>.txt` (formato Netscape) solo si existe la cookie de sesión (`sessionid` o `c_user`). Si la cuenta está conectada, se pasa `--cookies` a yt-dlp. `friendlyError` marca `needsLogin` para mostrar el botón "Conectar cuenta".

**Actualización de yt-dlp.** Las redes cambian seguido. La app actualiza yt-dlp en segundo plano una vez cada 24 h (`engine_last_update` en SharedPreferences), y también desde el menú lateral ("Actualizar motor de descarga"). Es lo primero que se debe probar cuando una red deja de funcionar.

**Compartir.** El manifest tiene un `intent-filter` `SEND text/plain`. Con la app cerrada, Dart lo pide con `takeSharedText`; con la app abierta, Kotlin llama a `sharedText`. `HomeScreen` detecta la red y abre `DownloadScreen` con el enlace, que se analiza solo.

**Pruebas hechas antes de elegir el motor (06/10/2026).** La API pública de tikwm funcionaba para videos sueltos, pero el listado de perfiles estaba bloqueado por Cloudflare. Facebook funcionaba leyendo `browser_native_hd_url` de la página pública. El endpoint GraphQL de Instagram respondía "rate limit / require_login". Por eso se eligió yt-dlp y el inicio de sesión opcional.

## Estado actual

- Repositorio: https://github.com/vperea95/downplayer (rama `main`).
- v1 compilada con éxito en Actions al primer intento (06/10/2026; el artifact con los 2 APK pesa unos 119 MB). Falta probarla en un celular.
- v1.1: ícono propio en todo lado y selección de calidad con peso aproximado. Sin compilar todavía.

## Pendientes e ideas

- Llave de firma fija (keystore en GitHub Secrets) para actualizar sin desinstalar ni perder el historial.
- Descargas en segundo plano con un servicio en primer plano y una notificación de progreso (hoy siguen mientras Android no cierre la app).
- Fotos y carruseles de TikTok e Instagram (hoy se toma solo el primer video).
