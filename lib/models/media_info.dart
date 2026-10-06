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
    required this.heights,
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

  /// Alturas de video disponibles (1080, 720, ...), de mayor a menor. Vacía si es solo audio.
  final List<int> heights;
  final int? width;
  final int? height;

  /// Perfil o canal del autor, para "Descarga por lotes". Null si la red no lo permite.
  final String? collectionUrl;

  bool get hasVideo => heights.isNotEmpty || (height ?? 0) > 0;
  int? get bestHeight => heights.isNotEmpty ? heights.first : height;
  bool get isVertical => width != null && height != null && height! > width!;

  factory MediaInfo.fromJson(Map<String, dynamic> json, SocialNetwork network, String sourceUrl) {
    final formats = (json['formats'] as List?) ?? const [];
    final heights = <int>{};
    for (final f in formats) {
      if (f is! Map) continue;
      final vcodec = f['vcodec'];
      final h = _toInt(f['height']);
      if (h != null && h > 0 && vcodec != 'none') heights.add(h);
    }

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
      duration: _toDouble(json['duration']),
      viewCount: _toInt(json['view_count']),
      heights: heights.toList()..sort((a, b) => b.compareTo(a)),
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
