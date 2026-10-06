import 'social_network.dart';

/// Datos de un video, leídos del JSON de yt-dlp (`yt-dlp -J`).
class MediaInfo {
  const MediaInfo({
    required this.network,
    required this.id,
    required this.url,
    required this.title,
    required this.author,
    required this.thumbnail,
    required this.duration,
    required this.viewCount,
    required this.qualities,
    required this.audioBytes,
    required this.width,
    required this.height,
    required this.collectionUrl,
  });

  final SocialNetwork network;
  final String id;
  final String url;
  final String title;
  final String author;
  final String? thumbnail;
  final double? duration;
  final int? viewCount;

  /// Calidades de video disponibles, de mayor a menor. Vacía si es solo audio.
  final List<VideoQuality> qualities;

  /// Peso aproximado del mejor audio (para estimar el MP3 y sumar al video).
  final int? audioBytes;
  final int? width;
  final int? height;

  /// Perfil o canal del autor, para "Descarga por lotes". Null si la red no lo permite.
  final String? collectionUrl;

  bool get hasVideo => qualities.isNotEmpty || (height ?? 0) > 0;

  /// Calidad máxima, contada por el lado corto (un video vertical 1080x1920 es "1080p").
  int? get bestHeight {
    if (qualities.isNotEmpty) return qualities.first.p;
    if (width != null && height != null) return width! < height! ? width : height;
    return height;
  }

  bool get isVertical => width != null && height != null && height! > width!;

  factory MediaInfo.fromJson(Map<String, dynamic> json, SocialNetwork network, String sourceUrl) {
    final duration = _toDouble(json['duration']);
    final formats = (json['formats'] as List?)?.whereType<Map>().toList() ?? const [];

    // Mejor audio solo (para sumarlo a los videos que vienen sin sonido).
    int? audioBytes;
    for (final f in formats) {
      if (f['vcodec'] != 'none' || f['acodec'] == 'none' || f['acodec'] == null) continue;
      final size = _sizeOf(f, duration);
      if (size != null && (audioBytes == null || size > audioBytes)) audioBytes = size;
    }

    // Por cada calidad se toma el formato que yt-dlp preferiría: H.264 primero, luego el de más bitrate.
    final best = <int, Map>{};
    for (final f in formats) {
      final vcodec = '${f['vcodec'] ?? ''}';
      if (vcodec == 'none' || vcodec.startsWith('av01')) continue;
      final w = _toInt(f['width']);
      final h = _toInt(f['height']);
      if (h == null || h <= 0) continue;
      final p = w != null && w > 0 && w < h ? w : h;
      final current = best[p];
      if (current == null || _betterFormat(f, current)) best[p] = f;
    }
    final audioSize = audioBytes;
    final qualities = best.entries.map((e) {
      final f = e.value;
      var size = _sizeOf(f, duration);
      final hasAudio = f['acodec'] != null && f['acodec'] != 'none';
      if (size != null && !hasAudio && audioSize != null) size += audioSize;
      final fps = _toDouble(f['fps']);
      return VideoQuality(p: e.key, bytes: size, fps: fps?.round());
    }).toList()
      ..sort((a, b) => b.p.compareTo(a.p));

    final description = (json['description'] as String?)?.trim() ?? '';
    var title = (json['title'] as String?)?.trim() ?? '';
    // TikTok e Instagram suelen poner como título algo genérico; la descripción dice más.
    if ((title.isEmpty || title.startsWith('Video by') || title.startsWith('TikTok video')) &&
        description.isNotEmpty) {
      title = description;
    }
    if (title.isEmpty) title = '${network.label} ${json['id'] ?? ''}'.trim();

    final author = _firstText([json['channel'], json['uploader'], json['creator'], json['uploader_id']]);

    return MediaInfo(
      network: network,
      id: '${json['id'] ?? ''}',
      url: (json['webpage_url'] as String?) ?? sourceUrl,
      title: title,
      author: author,
      thumbnail: json['thumbnail'] as String? ?? _lastThumbnail(json['thumbnails']),
      duration: duration,
      viewCount: _toInt(json['view_count']),
      qualities: qualities,
      audioBytes: audioBytes,
      width: _toInt(json['width']),
      height: _toInt(json['height']),
      collectionUrl: _collectionUrl(json, network),
    );
  }

  static String? _collectionUrl(Map<String, dynamic> json, SocialNetwork network) {
    switch (network) {
      case SocialNetwork.tiktok:
        final user = _firstText([json['uploader'], json['uploader_id']]);
        if (user.isEmpty) return null;
        return 'https://www.tiktok.com/@$user';
      case SocialNetwork.youtube:
        final channel = _firstText([json['channel_url'], json['uploader_url']]);
        if (channel.isEmpty) return null;
        return '$channel/videos';
      case SocialNetwork.facebook:
      case SocialNetwork.instagram:
        return null;
    }
  }
}

/// Una calidad de video: "p" es el lado corto (720, 1080…), con peso y fps aproximados.
class VideoQuality {
  const VideoQuality({required this.p, this.bytes, this.fps});

  final int p;
  final int? bytes;
  final int? fps;
}

/// Un video dentro de un perfil, canal o lista (`yt-dlp -J --flat-playlist`).
class BatchEntry {
  const BatchEntry({
    required this.id,
    required this.url,
    required this.title,
    required this.thumbnail,
    required this.duration,
    required this.viewCount,
  });

  final String id;
  final String url;
  final String title;
  final String? thumbnail;
  final double? duration;
  final int? viewCount;

  static BatchEntry? fromJson(Map<String, dynamic> json, SocialNetwork network) {
    final id = '${json['id'] ?? ''}';
    var url = (json['url'] as String?) ?? (json['webpage_url'] as String?) ?? '';
    if (url.isEmpty && id.isEmpty) return null;
    if (!url.startsWith('http')) {
      if (network == SocialNetwork.youtube) {
        url = 'https://www.youtube.com/watch?v=$id';
      } else {
        return null;
      }
    }
    final title = _firstText([json['title'], json['description']]);
    return BatchEntry(
      id: id.isEmpty ? url : id,
      url: url,
      title: title.isEmpty ? network.label : title,
      thumbnail: json['thumbnail'] as String? ?? _lastThumbnail(json['thumbnails']),
      duration: _toDouble(json['duration']),
      viewCount: _toInt(json['view_count']),
    );
  }
}

bool _betterFormat(Map a, Map b) {
  final aH264 = '${a['vcodec'] ?? ''}'.startsWith('avc');
  final bH264 = '${b['vcodec'] ?? ''}'.startsWith('avc');
  if (aH264 != bH264) return aH264;
  return (_toDouble(a['tbr']) ?? 0) > (_toDouble(b['tbr']) ?? 0);
}

/// Peso en bytes: el exacto, el aproximado o bitrate x duración.
int? _sizeOf(Map f, double? duration) {
  final exact = _toInt(f['filesize']) ?? _toInt(f['filesize_approx']);
  if (exact != null && exact > 0) return exact;
  final tbr = _toDouble(f['tbr']);
  if (tbr != null && duration != null) return (tbr * 1000 / 8 * duration).round();
  return null;
}

int? _toInt(Object? v) => v is num ? v.toInt() : null;
double? _toDouble(Object? v) => v is num ? v.toDouble() : null;

String _firstText(List<Object?> values) {
  for (final v in values) {
    if (v is String && v.trim().isNotEmpty) return v.trim();
  }
  return '';
}

/// yt-dlp ordena las miniaturas de peor a mejor.
String? _lastThumbnail(Object? thumbnails) {
  if (thumbnails is! List) return null;
  for (final t in thumbnails.reversed) {
    if (t is Map && t['url'] is String) return t['url'] as String;
  }
  return null;
}
