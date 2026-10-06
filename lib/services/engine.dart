import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/media_info.dart';
import '../models/social_network.dart';

class EngineException implements Exception {
  const EngineException(this.message, {this.canceled = false, this.needsLogin = false});

  final String message;
  final bool canceled;

  /// La red pidió iniciar sesión (Instagram y Facebook, sobre todo).
  final bool needsLogin;

  @override
  String toString() => message;
}

enum EngineStatus { preparing, ready, failed }

typedef ProgressCallback = void Function(double? progress, int? etaSeconds, String line);

/// Motor de descarga: yt-dlp dentro de la app (youtubedl-android).
/// El código nativo está en plataforma/android/MainActivity.kt.
class Engine extends ChangeNotifier {
  Engine() {
    _channel.setMethodCallHandler(_onNativeCall);
  }

  static const _channel = MethodChannel('downplayer/engine');
  static const _lastUpdateKey = 'engine_last_update';

  EngineStatus status = EngineStatus.preparing;
  String? version;
  String? initError;
  bool updating = false;

  /// Enlaces que llegan con "Compartir -> DownPlayer" mientras la app está abierta.
  void Function(String text)? onSharedText;

  final _progressListeners = <String, ProgressCallback>{};

  static bool get isSupported => !kIsWeb && Platform.isAndroid;

  /// La primera vez descomprime Python y ffmpeg (tarda unos segundos).
  /// Después actualiza yt-dlp una vez al día, porque las redes cambian seguido.
  Future<void> init() async {
    if (!isSupported) {
      status = EngineStatus.failed;
      initError = 'DownPlayer solo funciona en Android.';
      notifyListeners();
      return;
    }
    status = EngineStatus.preparing;
    notifyListeners();
    try {
      version = await _channel.invokeMethod<String>('init');
      status = EngineStatus.ready;
    } on PlatformException catch (e) {
      status = EngineStatus.failed;
      initError = e.message;
    }
    notifyListeners();
    if (status == EngineStatus.ready) _dailyUpdate();
  }

  Future<void> _dailyUpdate() async {
    final prefs = await SharedPreferences.getInstance();
    final last = prefs.getInt(_lastUpdateKey) ?? 0;
    final elapsed = DateTime.now().millisecondsSinceEpoch - last;
    if (elapsed < const Duration(hours: 24).inMilliseconds) return;
    try {
      await update();
      await prefs.setInt(_lastUpdateKey, DateTime.now().millisecondsSinceEpoch);
    } catch (e) {
      debugPrint('No se pudo actualizar yt-dlp: $e');
    }
  }

  /// Descarga la versión más reciente de yt-dlp. Devuelve true si había una nueva.
  Future<bool> update() async {
    updating = true;
    notifyListeners();
    try {
      final result = await _invoke<String>('update');
      version = await _invoke<String>('version') ?? version;
      return result == 'done';
    } finally {
      updating = false;
      notifyListeners();
    }
  }

  Future<MediaInfo> getInfo(String url, SocialNetwork network, {String? cookies}) async {
    final out = await _invoke<String>('getInfo', {'url': url, 'playlist': false, 'cookies': cookies});
    final json = _decodeJson(out);
    if (json['_type'] == 'playlist') {
      // Por ejemplo, un carrusel de Instagram: se toma el primer video.
      final entries = (json['entries'] as List?)?.whereType<Map<String, dynamic>>().toList() ?? const [];
      final firstVideo = entries.where((e) => e['vcodec'] != 'none').firstOrNull ?? entries.firstOrNull;
      if (firstVideo == null) throw const EngineException('Esa publicación no tiene videos.');
      return MediaInfo.fromJson({...json, ...firstVideo}, network, url);
    }
    return MediaInfo.fromJson(json, network, url);
  }

  /// Videos de un perfil, canal o lista (hasta 60).
  Future<List<BatchEntry>> getCollection(String url, SocialNetwork network, {String? cookies}) async {
    final out = await _invoke<String>('getInfo', {'url': url, 'playlist': true, 'cookies': cookies});
    final json = _decodeJson(out);
    final entries = (json['entries'] as List?) ?? const [];
    return entries
        .whereType<Map<String, dynamic>>()
        .map((e) => BatchEntry.fromJson(e, network))
        .whereType<BatchEntry>()
        .toList();
  }

  /// Descarga a la caché de la app y devuelve la ruta del archivo.
  Future<String> download({
    required String id,
    required String url,
    required List<String> args,
    String? cookies,
    required ProgressCallback onProgress,
  }) async {
    _progressListeners[id] = onProgress;
    try {
      final path = await _invoke<String>('download', {
        'id': id,
        'url': url,
        'args': args,
        'cookies': cookies,
      });
      if (path == null) throw const EngineException('No se pudo descargar el archivo.');
      return path;
    } finally {
      _progressListeners.remove(id);
    }
  }

  Future<void> cancel(String id) => _invoke<bool>('cancel', {'id': id});

  /// Guarda en Películas/DownPlayer o Música/DownPlayer. Devuelve el content://
  Future<String> saveToGallery(String path, {required bool audio}) async {
    if (await _invoke<bool>('needsStoragePermission') ?? false) {
      final granted = await _invoke<bool>('requestStoragePermission') ?? false;
      if (!granted) {
        throw const EngineException('Sin permiso de almacenamiento no se puede guardar en la galería.');
      }
    }
    final uri = await _invoke<String>('saveToGallery', {'path': path, 'audio': audio});
    if (uri == null) throw const EngineException('No se pudo guardar en la galería.');
    return uri;
  }

  Future<bool> deleteMedia(String uri) async => await _invoke<bool>('deleteMedia', {'uri': uri}) ?? false;
  Future<bool> mediaExists(String uri) async => await _invoke<bool>('mediaExists', {'uri': uri}) ?? false;
  Future<bool> share(String uri, String mime) async =>
      await _invoke<bool>('share', {'uri': uri, 'mime': mime}) ?? false;
  Future<bool> openWith(String uri, String mime) async =>
      await _invoke<bool>('openWith', {'uri': uri, 'mime': mime}) ?? false;
  Future<bool> openUrl(String url) async => await _invoke<bool>('openUrl', {'url': url}) ?? false;

  /// Copia la sesión del WebView a un archivo que yt-dlp entiende. True si la sesión está abierta.
  Future<bool> saveCookies(SocialNetwork network) async {
    if (!network.supportsLogin) return false;
    return await _invoke<bool>('saveCookies', {
          'domain': network.cookieDomain,
          'required': network.sessionCookie,
        }) ??
        false;
  }

  Future<void> clearCookies(SocialNetwork network) async {
    if (!network.supportsLogin) return;
    await _invoke<void>('clearCookies', {'domain': network.cookieDomain});
  }

  /// Texto compartido desde otra app al abrir DownPlayer (solo se entrega una vez).
  Future<String?> takeSharedText() => _invoke<String>('takeSharedText');

  Future<dynamic> _onNativeCall(MethodCall call) async {
    switch (call.method) {
      case 'progress':
        final args = Map<String, dynamic>.from(call.arguments as Map);
        final listener = _progressListeners[args['id']];
        if (listener == null) return;
        final raw = (args['progress'] as num?)?.toDouble();
        final eta = (args['eta'] as num?)?.toInt();
        listener(
          raw == null || raw < 0 ? null : (raw / 100).clamp(0.0, 1.0),
          eta == null || eta < 0 ? null : eta,
          '${args['line'] ?? ''}',
        );
      case 'sharedText':
        final text = call.arguments as String?;
        if (text != null) onSharedText?.call(text);
    }
  }

  Map<String, dynamic> _decodeJson(String? out) {
    if (out == null || out.trim().isEmpty) {
      throw const EngineException('No se encontró información del video.');
    }
    // Si yt-dlp imprime avisos antes del JSON, se toma desde la primera llave.
    final start = out.indexOf('{');
    try {
      return jsonDecode(start > 0 ? out.substring(start) : out) as Map<String, dynamic>;
    } catch (_) {
      throw const EngineException('No se pudo leer la información del video.');
    }
  }

  Future<T?> _invoke<T>(String method, [Map<String, dynamic>? args]) async {
    if (!isSupported) throw const EngineException('DownPlayer solo funciona en Android.');
    try {
      return await _channel.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      if (e.code == 'canceled') throw const EngineException('Descarga cancelada.', canceled: true);
      throw friendlyError(e.message ?? '');
    }
  }

  /// Convierte los errores de yt-dlp en mensajes que cualquiera entiende.
  static EngineException friendlyError(String raw) {
    final text = raw.toLowerCase();
    bool has(String s) => text.contains(s);

    if (has('login required') ||
        has('requested content is not available') ||
        has('rate-limit reached') ||
        has('use --cookies') ||
        has('cookies-from-browser') ||
        has('log in') ||
        has('login_required')) {
      return const EngineException(
        'La red pidió iniciar sesión para ver este video. Conecta tu cuenta desde el menú e intenta de nuevo.',
        needsLogin: true,
      );
    }
    if (has('sign in to confirm') || has('not a bot')) {
      return const EngineException(
        'YouTube pidió verificar que no eres un robot. Espera unos minutos, '
        'actualiza el motor desde el menú y vuelve a intentar.',
      );
    }
    if (has('private video') || has('is private') || has('this video is private')) {
      return const EngineException('El video es privado. Solo se pueden descargar videos públicos.');
    }
    if (has('unsupported url')) {
      return const EngineException('Ese enlace no es de un video que se pueda descargar. Revisa el enlace.');
    }
    if (has('video unavailable') || has('http error 404') || has('not found') || has('has been removed')) {
      return const EngineException('No se encontró el video. Puede que lo hayan borrado o que el enlace esté mal.');
    }
    if (has('age') && has('restrict') || has('inappropriate for some users')) {
      return const EngineException('El video tiene restricción de edad y no se puede descargar sin cuenta.');
    }
    if (has('live event') || has('is live') || has('premieres in')) {
      return const EngineException('Las transmisiones en vivo no se pueden descargar.');
    }
    if (has('unable to download') ||
        has('failed to resolve') ||
        has('network is unreachable') ||
        has('timed out') ||
        has('connection') ||
        has('temporary failure')) {
      return const EngineException('No hay conexión o la red no respondió. Revisa tu internet e intenta de nuevo.');
    }
    if (has('no space left')) {
      return const EngineException('No hay espacio suficiente en el celular.');
    }

    // Último recurso: la línea "ERROR:" de yt-dlp, sin el prefijo técnico.
    final line = raw
        .split('\n')
        .map((l) => l.trim())
        .lastWhere((l) => l.startsWith('ERROR:'), orElse: () => raw.trim());
    final cleaned = line.replaceFirst('ERROR:', '').replaceFirst(RegExp(r'^\s*\[[^\]]+\]\s*[^:]*:\s*'), '').trim();
    return EngineException(cleaned.isEmpty ? 'Algo salió mal. Intenta de nuevo.' : 'No se pudo descargar: $cleaned');
  }
}
