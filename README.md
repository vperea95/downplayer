# DownPlayer

App en Flutter para Android que descarga videos y audio de **TikTok, Facebook, Instagram y YouTube**, sin publicidad.

## Qué hace

- Menú principal para elegir la red y pegar el enlace. Si el portapapeles tiene un enlace de esa red, se pega solo.
- Vista previa del video con autor, vistas y duración.
- **Obtener Full HD**: elige la calidad (4K, Full HD, HD, 480p…). Los videos de TikTok se descargan sin marca de agua.
- **Obtener audio**: MP3 de la mejor calidad.
- **Descarga por lotes**: todos los videos de un perfil de TikTok o de un canal o lista de YouTube.
- **Historial** con descargas en curso, filtro de videos y audios, reproductor propio, compartir y borrar.
- Guarda en la galería: `Películas/DownPlayer` y `Música/DownPlayer`.
- "Compartir → DownPlayer" desde TikTok, Facebook, Instagram o YouTube.
- Conexión opcional de cuentas de Instagram y Facebook para los videos que piden iniciar sesión.
- El motor (yt-dlp) se actualiza solo una vez al día, y también desde el menú.

## Cómo se compila

GitHub Actions compila el APK en cada push a `main` (ver `.github/workflows/compilar-apk.yml`). El APK queda en la pestaña **Actions**, dentro del artifact `downplayer-apk`. Instala `app-arm64-v8a-release.apk`.

## Aviso

Descarga solo contenido que te pertenezca o que tengas permiso de guardar. Respeta los derechos de autor y las condiciones de cada red.
