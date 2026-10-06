import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/download.dart';
import '../models/media_info.dart';
import '../models/social_network.dart';
import '../services/accounts_service.dart';
import '../services/download_manager.dart';
import '../services/engine.dart';
import '../services/preferences_service.dart';
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
    required this.preferences,
    this.title,
  });

  final SocialNetwork network;
  final String url;
  final String? title;
  final Engine engine;
  final DownloadManager manager;
  final AccountsService accounts;
  final PreferencesService preferences;

  @override
  State<BatchScreen> createState() => _BatchScreenState();
}

class _BatchScreenState extends State<BatchScreen> {
  List<BatchEntry>? _entries;
  String? _error;
  final Set<String> _selected = {};
  late DownloadOption _option = widget.preferences.preferredOption ?? const DownloadOption.video();

  /// Calidades para los lotes: cada video baja en la elegida o, si no la tiene, en la más cercana por debajo.
  static const _choices = [
    DownloadOption.video(),
    DownloadOption.video(maxHeight: 1080),
    DownloadOption.video(maxHeight: 720),
    DownloadOption.video(maxHeight: 480),
    DownloadOption.video(maxHeight: 360),
    DownloadOption.audio(),
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  int _choiceIndex() {
    final i = _choices.indexWhere((c) => c.isAudio == _option.isAudio && c.maxHeight == _option.maxHeight);
    return i < 0 ? 0 : i;
  }

  String _choiceLabel(S s, DownloadOption o) {
    if (o.isAudio) return s.audioOnlyMp3;
    if (o.maxHeight == null) return s.bestAvailable;
    return s.upTo(qualityName(o.maxHeight!));
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
        option: _option,
      );
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(S.of(context).batchQueued(chosen.length))),
    );
    widget.preferences.rememberOption(_option);
    setState(_selected.clear);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final entries = _entries;
    final allSelected = entries != null && entries.isNotEmpty && _selected.length == entries.length;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title?.isNotEmpty == true ? widget.title! : s.batchDownload,
            maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          if (entries != null && entries.isNotEmpty)
            TextButton(
              onPressed: _toggleAll,
              child: Text(allSelected ? s.selectNone : s.selectAll),
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
                    InputDecorator(
                      decoration: InputDecoration(
                        labelText: s.quality,
                        prefixIcon: const Icon(Icons.high_quality),
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<int>(
                          value: _choiceIndex(),
                          isExpanded: true,
                          items: [
                            for (var i = 0; i < _choices.length; i++)
                              DropdownMenuItem(value: i, child: Text(_choiceLabel(s, _choices[i]))),
                          ],
                          onChanged: (i) {
                            if (i != null) setState(() => _option = _choices[i]);
                          },
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: FilledButton.icon(
                        onPressed: _selected.isEmpty ? null : _downloadSelected,
                        icon: const Icon(Icons.download),
                        label: Text(_selected.isEmpty ? s.chooseVideos : s.downloadNVideos(_selected.length)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _body(List<BatchEntry>? entries) {
    final s = S.of(context);
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
                s.batchLoadError(_error!),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(onPressed: _load, child: Text(s.retry)),
            ],
          ),
        ),
      );
    }
    if (entries == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(s.loadingVideos),
          ],
        ),
      );
    }
    if (entries.isEmpty) {
      return Center(child: Text(s.noVideos));
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
