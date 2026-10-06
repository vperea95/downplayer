import 'package:flutter/material.dart';

import '../models/download.dart';
import '../models/media_info.dart';
import '../services/preferences_service.dart';
import '../utils/format_utils.dart';

/// Hoja inferior para elegir la calidad del video (todas las que permita) o el audio MP3.
/// Marca la calidad que el usuario eligió la última vez y la recuerda.
Future<DownloadOption?> showQualitySheet(
  BuildContext context,
  MediaInfo info,
  PreferencesService preferences,
) async {
  // Sin repetir nombres (p. ej. 1080 y 1088 son ambos "Full HD").
  final seen = <String>{};
  final qualities = <VideoQuality>[];
  for (final q in info.qualities) {
    if (seen.add(qualityName(q.p))) qualities.add(q);
  }
  final preferred = _closestTo(preferences.preferredOption, qualities);

  final option = await showModalBottomSheet<DownloadOption>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (context) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: qualities.length > 4 ? 0.7 : 0.5,
      minChildSize: 0.3,
      maxChildSize: 0.9,
      builder: (context, scroll) => SafeArea(
        child: ListView(
          controller: scroll,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 4),
              child: Text('Elige la calidad', style: Theme.of(context).textTheme.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                'Más calidad = mejor imagen, pero ocupa más espacio.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (info.hasVideo) ...[
              if (qualities.isEmpty)
                _OptionTile(
                  icon: Icons.movie_outlined,
                  title: info.bestHeight != null ? qualityName(info.bestHeight!) : 'Video MP4',
                  details: 'Única calidad disponible',
                  option: const DownloadOption.video(),
                  selected: preferred?.isAudio == false,
                ),
              for (var i = 0; i < qualities.length; i++)
                _OptionTile(
                  icon: i == 0 ? Icons.high_quality : Icons.movie_outlined,
                  title: qualityName(qualities[i].p),
                  details: _details(qualities[i], best: i == 0),
                  // La mejor se pide como "la mejor disponible" para no perderla si cambia un poco.
                  option: i == 0 ? const DownloadOption.video() : DownloadOption.video(maxHeight: qualities[i].p),
                  selected: preferred != null &&
                      !preferred.isAudio &&
                      (i == 0 ? preferred.maxHeight == null : preferred.maxHeight == qualities[i].p),
                ),
            ],
            const Divider(),
            _OptionTile(
              icon: Icons.music_note,
              title: 'Solo audio MP3',
              details: [
                'La mejor calidad de sonido',
                if (info.audioBytes != null) '≈ ${formatBytes(info.audioBytes)}',
              ].join(' · '),
              option: const DownloadOption.audio(),
              selected: preferred?.isAudio == true,
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );

  if (option != null) await preferences.rememberOption(option);
  return option;
}

/// Lleva la preferencia guardada a una calidad que este video sí tenga
/// (si prefería 1080p y el video llega a 720p, se marca 720p).
DownloadOption? _closestTo(DownloadOption? preferred, List<VideoQuality> qualities) {
  if (preferred == null || preferred.isAudio || preferred.maxHeight == null || qualities.isEmpty) {
    return preferred;
  }
  final target = preferred.maxHeight!;
  if (target >= qualities.first.p) return const DownloadOption.video();
  for (final q in qualities) {
    if (q.p <= target) return DownloadOption.video(maxHeight: q.p);
  }
  return DownloadOption.video(maxHeight: qualities.last.p);
}

String _details(VideoQuality q, {required bool best}) {
  return [
    if (best) 'Máxima calidad',
    if (q.p <= 480 && !best) 'Ocupa poco espacio',
    if (q.fps != null && q.fps! >= 50) '${q.fps} fps',
    if (q.bytes != null) '≈ ${formatBytes(q.bytes)}',
  ].join(' · ');
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.details,
    required this.option,
    this.selected = false,
  });

  final IconData icon;
  final String title;
  final String details;
  final DownloadOption option;

  /// La calidad que eligió la última vez.
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      selected: selected,
      selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.5),
      leading: Icon(icon),
      title: Row(
        children: [
          Flexible(child: Text(title, style: const TextStyle(fontWeight: FontWeight.w700))),
          if (selected) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(10)),
              child: Text('Tu preferida', style: TextStyle(color: scheme.onPrimary, fontSize: 11)),
            ),
          ],
        ],
      ),
      subtitle: details.isEmpty ? null : Text(details),
      trailing: const Icon(Icons.download),
      onTap: () => Navigator.pop(context, option),
    );
  }
}
