import 'package:flutter/material.dart';

import '../models/download.dart';
import '../models/media_info.dart';

/// Hoja inferior para elegir la calidad del video o el audio MP3.
Future<DownloadOption?> showQualitySheet(BuildContext context, MediaInfo info) {
  // Se muestran como máximo 5 calidades, sin repetir nombres (p. ej. 1080 y 1088).
  final seen = <String>{};
  final heights = <int>[];
  for (final h in info.heights) {
    if (seen.add(qualityName(h)) && heights.length < 5) heights.add(h);
  }

  return showModalBottomSheet<DownloadOption>(
    context: context,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('¿Qué quieres descargar?', style: Theme.of(context).textTheme.titleMedium),
            ),
            if (info.hasVideo) ...[
              _OptionTile(
                icon: Icons.high_quality,
                title: 'Mejor calidad',
                subtitle: info.bestHeight != null ? qualityName(info.bestHeight!) : 'Video MP4',
                option: const DownloadOption.video(),
                highlighted: true,
              ),
              for (final h in heights.skip(1))
                _OptionTile(
                  icon: Icons.movie_outlined,
                  title: qualityName(h),
                  subtitle: h <= 480 ? 'Ocupa menos espacio' : 'Video MP4',
                  option: DownloadOption.video(maxHeight: h),
                ),
            ],
            const _OptionTile(
              icon: Icons.music_note,
              title: 'Solo audio',
              subtitle: 'MP3 de la mejor calidad',
              option: DownloadOption.audio(),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.option,
    this.highlighted = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final DownloadOption option;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Icon(icon, color: highlighted ? scheme.primary : null),
      title: Text(title, style: highlighted ? const TextStyle(fontWeight: FontWeight.w700) : null),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.download),
      onTap: () => Navigator.pop(context, option),
    );
  }
}
