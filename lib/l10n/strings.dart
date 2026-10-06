import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Textos de la app en español e inglés. Se elige según el idioma del sistema
/// (o el que el usuario escoja en el menú): español si el celular está en
/// español, inglés en cualquier otro idioma.
///
/// En pantallas: `S.of(context).texto` (se actualiza solo si cambia el idioma).
/// En servicios sin contexto: `S.current.texto`.
class S {
  const S._(this.languageCode);

  final String languageCode;

  /// El primero es el idioma de respaldo cuando el sistema está en otro idioma.
  static const supportedLocales = [Locale('en'), Locale('es')];

  static S current = const S._('es');

  static S of(BuildContext context) => Localizations.of<S>(context, S) ?? current;

  static S forLocale(Locale locale) => S._(locale.languageCode == 'es' ? 'es' : 'en');

  static const LocalizationsDelegate<S> delegate = _SDelegate();

  bool get isSpanish => languageCode == 'es';
  String _t(String es, String en) => isSpanish ? es : en;

  // ---------- Generales ----------
  String get cancel => _t('Cancelar', 'Cancel');
  String get retry => _t('Reintentar', 'Try again');
  String get view => _t('Ver', 'View');
  String get share => _t('Compartir', 'Share');
  String get openWithApp => _t('Abrir con otra app', 'Open with another app');
  String get openWithTitle => _t('Abrir con', 'Open with');
  String get done => _t('Listo', 'Done');
  String get delete => _t('Eliminar', 'Delete');
  String get options => _t('Opciones', 'Options');
  String get remove => _t('Quitar', 'Remove');
  String get download => _t('Descargar', 'Download');
  String get error => _t('Error', 'Error');
  String openNetwork(String network) => _t('Abrir $network', 'Open $network');
  String connectNetwork(String network) => _t('Conectar $network', 'Connect $network');
  String accountConnected(String network) => _t('Cuenta de $network conectada.', '$network account connected.');

  // ---------- Marca ----------
  String get tagline => _t('Descarga sin publicidad', 'Download without ads');
  String get byVixago => _t('por Vixago', 'by Vixago');
  String get legalese => '© 2026 Vixago';
  String get aboutText => _t(
        'Descarga videos y audio de TikTok, Facebook, Instagram y YouTube, sin publicidad. '
            'Usa el motor libre yt-dlp. Descarga solo contenido que tengas derecho a guardar.\n\n'
            'Desarrollada por Vixago.',
        'Download videos and audio from TikTok, Facebook, Instagram and YouTube, without ads. '
            'Powered by the free yt-dlp engine. Only download content you have the right to save.\n\n'
            'Developed by Vixago.',
      );

  // ---------- Inicio ----------
  String get tabHome => _t('Inicio', 'Home');
  String get tabHistory => _t('Historial', 'History');
  String get whereFrom => _t('¿De dónde es el video?', 'Where is the video from?');
  String get chooseNetwork => _t('Elige la red y pega el enlace.', 'Choose the app and paste the link.');
  String get faster => _t('Más rápido', 'Even faster');
  String get fasterHint => _t(
        'En TikTok, Facebook, Instagram o YouTube toca "Compartir" y elige DownPlayer. La app abre el video sola.',
        'In TikTok, Facebook, Instagram or YouTube tap "Share" and choose DownPlayer. The app opens the video for you.',
      );
  String get tiktokTagline => _t('Sin marca de agua', 'No watermark');
  String get facebookTagline => _t('Videos y reels', 'Videos and reels');
  String get instagramTagline => _t('Reels y videos', 'Reels and videos');
  String get youtubeTagline => _t('Videos, Shorts y MP3', 'Videos, Shorts and MP3');
  String get sharedNoLink => _t('Lo que compartiste no tiene un enlace.', "What you shared doesn't contain a link.");
  String get sharedUnsupported => _t(
        'Ese enlace no es de TikTok, Facebook, Instagram ni YouTube.',
        "That link isn't from TikTok, Facebook, Instagram or YouTube.",
      );
  String savedToGallery(String title) => _t('Guardado en la galería: $title', 'Saved to gallery: $title');

  // ---------- Motor ----------
  String get enginePreparing => _t('Preparando el motor de descarga…', 'Preparing the download engine…');
  String get enginePreparingHint => _t('La primera vez tarda unos segundos.', 'The first time takes a few seconds.');
  String get engineFailed => _t('El motor de descarga no arrancó', "The download engine didn't start");
  String get enginePreparingWait =>
      _t('El motor de descarga se está preparando. Espera unos segundos.', 'The download engine is getting ready. Wait a few seconds.');
  String get updateEngine => _t('Actualizar motor de descarga', 'Update download engine');
  String get updateEngineHint => _t('Úsalo si las descargas fallan', 'Use it if downloads fail');
  String engineVersion(String v) => _t('Versión $v', 'Version $v');
  String get engineChecking => _t('Buscando la versión más reciente del motor…', 'Looking for the latest engine version…');
  String engineUpdated(String v) => _t('Motor actualizado a la versión $v.', 'Engine updated to version $v.');
  String get engineUpToDate => _t('El motor ya está en la versión más reciente.', 'The engine is already up to date.');
  String engineUpdateFailed(String msg) => _t('No se pudo actualizar: $msg', "Couldn't update: $msg");

  // ---------- Menú lateral ----------
  String get accountsOptional => _t('Cuentas (opcional)', 'Accounts (optional)');
  String get accountsHint =>
      _t('Solo hace falta si un video dice que pide iniciar sesión.', 'Only needed when a video asks you to log in.');
  String get connected => _t('Conectada', 'Connected');
  String get notConnected => _t('Sin conectar', 'Not connected');
  String get connect => _t('Conectar', 'Connect');
  String get logout => _t('Salir', 'Log out');
  String disconnectTitle(String network) => _t('¿Desconectar $network?', 'Disconnect $network?');
  String get disconnectBody => _t('Algunos videos pueden dejar de descargarse.', 'Some videos may stop downloading.');
  String get disconnect => _t('Desconectar', 'Disconnect');
  String get settings => _t('Ajustes', 'Settings');
  String get appearance => _t('Apariencia', 'Appearance');
  String get themeSystem => _t('Predeterminado del sistema', 'System default');
  String get themeLight => _t('Claro', 'Light');
  String get themeDark => _t('Oscuro', 'Dark');
  String get language => _t('Idioma', 'Language');
  String get languageSystem => _t('Automático (del sistema)', 'Automatic (system)');
  String get about => _t('Acerca de', 'About');

  // ---------- Pantalla de descarga ----------
  String get noLinkCopied => _t('No hay ningún enlace copiado.', 'There is no copied link.');
  String pasteLinkOf(String network, String example) =>
      _t('Pega un enlace de $network. Por ejemplo: $example', 'Paste a $network link. For example: $example');
  String linkIsFrom(String network) =>
      _t('Ese enlace es de $network. Lo abrimos como $network.', 'That link is from $network. Opening it as $network.');
  String downloading(String label) => _t('Descargando ${label.toLowerCase()}…', 'Downloading ${label.toLowerCase()}…');
  String pasteHint(String network) => _t('Pega el enlace de $network', 'Paste the $network link');
  String get clear => _t('Borrar', 'Clear');
  String get paste => _t('Pegar', 'Paste');
  String get pasteCopied => _t('Pegar enlace copiado', 'Paste copied link');
  String get searchingVideo => _t('Buscando el video…', 'Looking for the video…');
  String get couldNotGetVideo => _t('No se pudo obtener el video', "Couldn't get the video");
  String get getVideo => _t('Obtener video', 'Get video');
  String get getFullHd => _t('Obtener Full HD', 'Get Full HD');
  String get getHd => _t('Obtener HD', 'Get HD');
  String get getAudio => _t('Obtener audio', 'Get audio');
  String get batchDownload => _t('Descarga por lotes', 'Batch download');
  String get chooseQualityAndDownload => _t('Elegir calidad y descargar', 'Choose quality and download');
  String chooseQualityUpTo(String quality) =>
      _t('Elegir calidad y descargar (hasta $quality)', 'Choose quality and download (up to $quality)');
  String get howTo => _t('Cómo descargar', 'How to download');
  String howStep1(String network) => _t('Abre $network y busca el video.', 'Open $network and find the video.');
  String get howStep2 => _t('Toca "Compartir" y luego "Copiar enlace".', 'Tap "Share" and then "Copy link".');
  String get howStep3 =>
      _t('Vuelve aquí: el enlace se pega solo. Toca "Descargar".', 'Come back here: the link pastes itself. Tap "Download".');
  String shareTip(String network) => _t(
        'También puedes tocar "Compartir" en $network y elegir DownPlayer.',
        'You can also tap "Share" in $network and choose DownPlayer.',
      );
  String get collectionTip => _t(
        'Si pegas el enlace de un perfil, canal o lista, verás todos sus videos para descargarlos juntos.',
        'If you paste a profile, channel or playlist link, you will see all its videos to download them together.',
      );

  // ---------- Calidad ----------
  String get chooseQuality => _t('Elige la calidad', 'Choose the quality');
  String get qualityHint =>
      _t('Más calidad = mejor imagen, pero ocupa más espacio.', 'Higher quality = better picture, but takes more space.');
  String get onlyQuality => _t('Única calidad disponible', 'Only available quality');
  String get videoMp4 => _t('Video MP4', 'MP4 video');
  String get audioOnlyMp3 => _t('Solo audio MP3', 'Audio only (MP3)');
  String get bestSound => _t('La mejor calidad de sonido', 'Best sound quality');
  String get maxQuality => _t('Máxima calidad', 'Highest quality');
  String get smallSize => _t('Ocupa poco espacio', 'Small file');
  String get yourFavorite => _t('Tu preferida', 'Your favorite');
  String get quality => _t('Calidad', 'Quality');
  String get bestAvailable => _t('Mejor calidad disponible', 'Best available quality');
  String upTo(String quality) => _t('Hasta $quality', 'Up to $quality');
  String get labelAudio => _t('Audio MP3', 'MP3 audio');
  String get labelVideoBest => _t('Video (mejor calidad)', 'Video (best quality)');
  String labelVideo(String quality) => _t('Video $quality', 'Video $quality');

  // ---------- Lotes ----------
  String batchQueued(int n) =>
      _t('$n descargas en cola. Míralas en Historial.', '$n downloads queued. See them in History.');
  String get selectNone => _t('Ninguno', 'None');
  String get selectAll => _t('Todos', 'All');
  String get chooseVideos => _t('Elige los videos', 'Choose the videos');
  String downloadNVideos(int n) => n == 1 ? _t('Descargar 1 video', 'Download 1 video') : _t('Descargar $n videos', 'Download $n videos');
  String batchLoadError(String error) =>
      _t('No se pudieron cargar los videos de este perfil.\n$error', "Couldn't load this profile's videos.\n$error");
  String get loadingVideos => _t('Cargando videos… puede tardar un poco', 'Loading videos… this may take a moment');
  String get noVideos => _t('No se encontraron videos.', 'No videos found.');

  // ---------- Descargas en curso ----------
  String get waiting => _t('En espera…', 'Waiting…');
  String get convertingMp3 => _t('Convirtiendo a MP3…', 'Converting to MP3…');
  String get merging => _t('Uniendo video y audio…', 'Joining video and audio…');
  String get connecting => _t('Conectando…', 'Connecting…');
  String timeLeft(String time) => _t(' · faltan $time', ' · $time left');
  String get savingToGallery => _t('Guardando en la galería…', 'Saving to gallery…');
  String get canceling => _t('Cancelando…', 'Canceling…');
  String get connectAccount => _t('Conectar cuenta', 'Connect account');
  String somethingWrong(String e) => _t('Algo salió mal: $e', 'Something went wrong: $e');

  // ---------- Historial ----------
  String get deleteQuestion => _t('¿Eliminar?', 'Delete?');
  String get onlyFromHistory => _t('Solo del historial', 'Only from history');
  String get deleteFile => _t('Borrar archivo', 'Delete file');
  String get couldNotDelete =>
      _t('No se pudo borrar el archivo. Bórralo desde la galería.', "Couldn't delete the file. Delete it from the gallery.");
  String get play => _t('Reproducir', 'Play');
  String viewOn(String network) => _t('Ver en $network', 'View on $network');
  String downloadingCount(int n) => _t('Descargando ($n)', 'Downloading ($n)');
  String get downloaded => _t('Descargados', 'Downloaded');
  String get filterAll => _t('Todos', 'All');
  String get filterVideos => _t('Videos', 'Videos');
  String get filterAudios => _t('Audios', 'Audio');
  String get nothingYet => _t('Nada por aquí todavía.', 'Nothing here yet.');
  String get emptyHistory => _t(
        'Aquí verás tus descargas.\nSe guardan en la galería, en las carpetas Películas/DownPlayer y Música/DownPlayer.',
        'Your downloads will appear here.\nThey are saved to the gallery, in the Movies/DownPlayer and Music/DownPlayer folders.',
      );
  String get today => _t('Hoy', 'Today');
  String get yesterday => _t('Ayer', 'Yesterday');
  String get am => _t('a. m.', 'AM');
  String get pm => _t('p. m.', 'PM');

  // ---------- Reproductor ----------
  String get cannotOpenFile => _t(
        'No se pudo abrir el archivo. Puede que lo hayan borrado de la galería.',
        "Couldn't open the file. It may have been deleted from the gallery.",
      );

  // ---------- Inicio de sesión ----------
  String get notLoggedYet => _t(
        'Todavía no has iniciado sesión. Escribe tu usuario y contraseña.',
        "You haven't logged in yet. Enter your username and password.",
      );
  String loginBanner(String network) => _t(
        'Inicia sesión en la página oficial de $network. DownPlayer no ve tu contraseña; solo usa la sesión '
            'para descargar videos que la red no muestra sin cuenta.',
        'Log in on the official $network page. DownPlayer never sees your password; it only uses the session '
            'to download videos the app does not show without an account.',
      );

  // ---------- Errores del motor ----------
  String get androidOnly => _t('DownPlayer solo funciona en Android.', 'DownPlayer only works on Android.');
  String get postHasNoVideos => _t('Esa publicación no tiene videos.', "That post doesn't have videos.");
  String get downloadFileFailed => _t('No se pudo descargar el archivo.', "Couldn't download the file.");
  String get storagePermissionNeeded => _t(
        'Sin permiso de almacenamiento no se puede guardar en la galería.',
        "Without storage permission the file can't be saved to the gallery.",
      );
  String get saveFailed => _t('No se pudo guardar en la galería.', "Couldn't save to the gallery.");
  String get noVideoInfo => _t('No se encontró información del video.', 'No video information was found.');
  String get cannotReadInfo => _t('No se pudo leer la información del video.', "Couldn't read the video information.");
  String get downloadCanceled => _t('Descarga cancelada.', 'Download canceled.');
  String get errLogin => _t(
        'La red pidió iniciar sesión para ver este video. Conecta tu cuenta desde el menú e intenta de nuevo.',
        'The app asked to log in to see this video. Connect your account from the menu and try again.',
      );
  String get errBot => _t(
        'YouTube pidió verificar que no eres un robot. Espera unos minutos, actualiza el motor desde el menú y vuelve a intentar.',
        "YouTube asked to verify you're not a robot. Wait a few minutes, update the engine from the menu and try again.",
      );
  String get errPrivate =>
      _t('El video es privado. Solo se pueden descargar videos públicos.', 'The video is private. Only public videos can be downloaded.');
  String get errUnsupported =>
      _t('Ese enlace no es de un video que se pueda descargar. Revisa el enlace.', "That link isn't a downloadable video. Check the link.");
  String get errNotFound => _t(
        'No se encontró el video. Puede que lo hayan borrado o que el enlace esté mal.',
        'The video was not found. It may have been deleted or the link is wrong.',
      );
  String get errAge => _t(
        'El video tiene restricción de edad y no se puede descargar sin cuenta.',
        "The video is age-restricted and can't be downloaded without an account.",
      );
  String get errLive => _t('Las transmisiones en vivo no se pueden descargar.', "Live streams can't be downloaded.");
  String get errNetwork => _t(
        'No hay conexión o la red no respondió. Revisa tu internet e intenta de nuevo.',
        "No connection or the server didn't respond. Check your internet and try again.",
      );
  String get errNoSpace => _t('No hay espacio suficiente en el celular.', 'There is not enough space on the phone.');
  String get errGeneric => _t('Algo salió mal. Intenta de nuevo.', 'Something went wrong. Try again.');
  String errWithDetail(String detail) => _t('No se pudo descargar: $detail', "Couldn't download: $detail");
}

class _SDelegate extends LocalizationsDelegate<S> {
  const _SDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<S> load(Locale locale) {
    final strings = S.forLocale(locale);
    S.current = strings;
    return SynchronousFuture(strings);
  }

  @override
  bool shouldReload(_SDelegate old) => false;
}
