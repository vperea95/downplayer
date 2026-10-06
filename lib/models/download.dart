import 'social_network.dart';

enum MediaKind { video, audio }

/// Qué se descarga: video en cierta calidad o audio MP3. Se traduce a opciones de yt-dlp.
class DownloadOption {
  const DownloadOption.video({this.maxHeight}) : kind = MediaKind.video;
  const DownloadOption.audio()
      : kind = MediaKind.audio,
        maxHeight = null;

  final MediaKind kind;

  /// Calidad máxima contada por el lado corto (720, 1080…), igual que el campo
  /// "res" de yt-dlp. Null = la mejor calidad disponible.
  final int? maxHeight;

  bool get isAudio => kind == MediaKind.audio;

  String get label {
    if (isAudio) return 'Audio MP3';
    if (maxHeight == null) return 'Video (mejor calidad)';
    return 'Video ${qualityName(maxHeight!)}';
  }

  /// Opciones para yt-dlp. Se prefiere H.264 + AAC en MP4 porque se reproduce en
  /// cualquier celular; AV1 se evita porque muchos equipos no lo pueden abrir.
  List<String> toArgs() {
    if (isAudio) {
      return ['-f', 'ba/b', '-x', '--audio-format', 'mp3', '--audio-quality', '0'];
    }
    final res = maxHeight == null ? 'res' : 'res:$maxHeight';
    return [
      '-f', 'bv*[vcodec!^=av01]+ba/b/bv*+ba',
      '-S', '$res,vcodec:h264,acodec:aac',
      '--merge-output-format', 'mp4',
    ];
  }
}

/// 2160 -> "4K", 1080 -> "Full HD 1080p", 720 -> "HD 720p". Se cuenta por el lado corto.
String qualityName(int height) {
  if (height >= 2160) return '4K';
  if (height >= 1440) return '2K 1440p';
  if (height >= 1080) return 'Full HD ${height}p';
  if (height >= 720) return 'HD ${height}p';
  return '${height}p';
}

enum TaskState { queued, running, saving, failed, canceled }

/// Una descarga en curso o en cola (las terminadas pasan al historial).
class DownloadTask {
  DownloadTask({
    required this.id,
    required this.network,
    required this.url,
    required this.title,
    required this.author,
    required this.thumbnail,
    required this.option,
  });

  final String id;
  final SocialNetwork network;
  final String url;
  final String title;
  final String author;
  final String? thumbnail;
  final DownloadOption option;

  TaskState state = TaskState.queued;

  /// 0 a 1, o null si no se sabe todavía.
  double? progress;
  int? etaSeconds;

  /// "Procesando…" mientras ffmpeg une video y audio o convierte a MP3.
  bool processing = false;
  String? error;

  /// Para avisar en la pantalla de descarga cuando la red pide iniciar sesión.
  bool needsLogin = false;

  bool get isActive => state == TaskState.queued || state == TaskState.running || state == TaskState.saving;
}

/// Un archivo ya descargado y guardado en la galería.
class HistoryEntry {
  const HistoryEntry({
    required this.id,
    required this.network,
    required this.kind,
    required this.title,
    required this.author,
    required this.uri,
    required this.mime,
    required this.sourceUrl,
    required this.createdAt,
    this.thumbnailPath,
  });

  final String id;
  final SocialNetwork network;
  final MediaKind kind;
  final String title;
  final String author;

  /// content:// del archivo en la galería.
  final String uri;
  final String mime;
  final String sourceUrl;
  final DateTime createdAt;

  /// Copia local de la miniatura (los enlaces de las redes caducan).
  final String? thumbnailPath;

  bool get isAudio => kind == MediaKind.audio;

  Map<String, dynamic> toJson() => {
        'id': id,
        'network': network.name,
        'kind': kind.name,
        'title': title,
        'author': author,
        'uri': uri,
        'mime': mime,
        'sourceUrl': sourceUrl,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'thumbnailPath': thumbnailPath,
      };

  static HistoryEntry? fromJson(Map<String, dynamic> json) {
    final network = SocialNetwork.byName('${json['network']}');
    final uri = json['uri'];
    if (network == null || uri is! String) return null;
    return HistoryEntry(
      id: '${json['id']}',
      network: network,
      kind: json['kind'] == 'audio' ? MediaKind.audio : MediaKind.video,
      title: '${json['title'] ?? ''}',
      author: '${json['author'] ?? ''}',
      uri: uri,
      mime: '${json['mime'] ?? 'video/mp4'}',
      sourceUrl: '${json['sourceUrl'] ?? ''}',
      createdAt: DateTime.fromMillisecondsSinceEpoch((json['createdAt'] as num?)?.toInt() ?? 0),
      thumbnailPath: json['thumbnailPath'] as String?,
    );
  }
}
