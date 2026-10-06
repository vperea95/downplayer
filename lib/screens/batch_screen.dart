import 'package:flutter/material.dart';

import '../models/download.dart';
import '../models/media_info.dart';
import '../models/social_network.dart';
import '../services/accounts_service.dart';
import '../services/download_manager.dart';
import '../services/engine.dart';
import '../utils/format_utils.dart';
import '../widgets/thumbnail.dart';

/// Videos de un perfil, canal o lista, para descargar varios a la vez.
class BatchScreen extends StatefulWidget {
  const BatchScreen({
    super.key,
    required this.network,
    required this.url,
    required this.engine,
    required this.manager,
    required this.accounts,
    this.title,
  });

  final SocialNetwork network;
  final String url;
  final String? title;
  final Engine engine;
  final DownloadManager manager;
  final AccountsService accounts;

  @override
  State<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends State<BatchScreen> {
  List<BatchEntry>? _entries;
  String? _error;
  final Set<String> _selected = {};
  bool _audioOnly = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _entries = null;
      _error = null;
    });
    try {
      final entries = await widget.engine.getCollection(
        widget.url,
        widget.network,
        cookies: widget.accounts.cookiesFor(widget.network),
      );
      if (!mounted) return;
      setState(() => _entries = entries);
    } on EngineException catch (e) {
      if (!mounted) return;
      setState(() => _error = e.message);
    }
  }

  void _toggle(BatchEntry entry) {
    setState(() {
      if (!_selected.remove(entry.id)) _selected.add(entry.id);
    });
  }

  void _toggleAll() {
    final entries = _entries ?? const [];
    setState(() {
      if (_selected.length == entries.length) {
        _selected.clear();
      } else {
        _selected
          ..clear()
          ..addAll(entries.map((e) => e.id));
      }
    });
  }

  void _downloadSelected() {
    final chosen = (_entries ?? const <BatchEntry>[]).where((e) => _selected.contains(e.id)).toList();
    if (chosen.isEmpty) return;
    for (final entry in chosen) {
      widget.manager.enqueue(
        network: widget.network,
        url: entry.url,
        title: entry.title,
        author: widget.title ?? '',
        thumbnail: entry.thumbnail,
        option: _audioOnly ? const DownloadOption.audio() : const DownloadOption.video(),
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('${chosen.length} descargas en cola. Míralas en Historial.')),
    );
    setState(_selected.clear);
  }

  @override
  Widget build(BuildContext context) {
    final entries = _entries;
    final allSelected = entries != null && entries.isNotEmpty && _selected.length == entries.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title?.isNotEmpty == true ? widget.title! : 'Descarga por lotes',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (entries != null && entries.isNotEmpty)
            TextButton(
              onPressed: _toggleAll,
              child: Text(allSelected ? 'Ninguno' : 'Todos'),
            ),
        ],
      ),
      body: _body(entries),
      bottomNavigationBar: entries == null || entries.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SegmentedButton<bool>(
                      segments: const [
                        ButtonSegment(value: false, icon: Icon(Icons.movie_outlined), label: Text('Video')),
                        ButtonSegment(value: true, icon: Icon(Icons.music_note), label: Text('Audio MP3')),
                      ],
                      selected: {_audioOnly},
                      onSelectionChanged: (s) => setState(() => _audioOnly = s.first),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _selected.isEmpty ? null : _downloadSelected,
                        icon: const Icon(Icons.download),
                        label: Text(_selected.isEmpty
                            ? 'Elige los videos'
                            : 'Descargar ${_selected.length} ${_selected.length == 1 ? 'video' : 'videos'}'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _body(List<BatchEntry>? entries) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48),
              const SizedBox(height: 12),
              Text(
                'No se pudieron cargar los videos de este perfil.\n$_error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: _load, child: const Text('Reintentar')),
            ],
          ),
        ),
      );
    }
    if (entries == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Cargando videos… puede tardar un poco'),
          ],
        ),
      );
    }
    if (entries.isEmpty) {
      return const Center(child: Text('No se encontraron videos.'));
    }

    final vertical = widget.network == SocialNetwork.tiktok;
    return GridView.builder(
      padding: const EdgeInsets.all(2),
      gridDelegate: SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: vertical ? 160 : 240,
        childAspectRatio: vertical ? 3 / 4 : 16 / 11,
        mainAxisSpacing: 2,
        crossAxisSpacing: 2,
      ),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final entry = entries[i];
        final selected = _selected.contains(entry.id);
        return GestureDetector(
          onTap: () => _toggle(entry),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Thumbnail(network: widget.network, url: entry.thumbnail),
              // Sin miniatura (pasa en algunos perfiles): se muestra el título.
              if (entry.thumbnail == null)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Align(
                    alignment: Alignment.bottomLeft,
                    child: Text(entry.title, maxLines: 3, overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall),
                  ),
                ),
              if (selected) ColoredBox(color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.35)),
              Positioned(
                right: 6,
                top: 6,
                child: Icon(
                  selected ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: Colors.white,
                  shadows: const [Shadow(blurRadius: 4)],
                ),
              ),
              if (entry.duration != null)
                Positioned(
                  left: 6,
                  bottom: 6,
                  child: Text(formatDuration(entry.duration),
                      style: const TextStyle(color: Colors.white, shadows: [Shadow(blurRadius: 4)])),
                ),
            ],
          ),
        );
      },
    );
  }
}
