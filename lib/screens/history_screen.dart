import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/download.dart';
import '../services/accounts_service.dart';
import '../services/download_manager.dart';
import '../services/engine.dart';
import '../services/history_service.dart';
import '../theme.dart';
import '../utils/format_utils.dart';
import '../widgets/network_logo.dart';
import '../widgets/task_tile.dart';
import '../widgets/thumbnail.dart';
import 'login_screen.dart';
import 'player_screen.dart';

enum _Filter { all, video, audio }

/// Descargas en curso arriba y, debajo, todo lo descargado.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({
    super.key,
    required this.engine,
    required this.manager,
    required this.history,
    required this.accounts,
  });

  final Engine engine;
  final DownloadManager manager;
  final HistoryService history;
  final AccountsService accounts;

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  _Filter _filter = _Filter.all;

  void _play(HistoryEntry entry) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => PlayerScreen(entry: entry, engine: widget.engine)),
    );
  }

  Future<void> _delete(HistoryEntry entry) async {
    final s = S.of(context);
    final deleteFile = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(s.deleteQuestion),
        content: Text('"${entry.title}"'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.onlyFromHistory)),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.deleteFile)),
        ],
      ),
    );
    if (deleteFile == null) return;
    if (deleteFile) {
      final ok = await widget.engine.deleteMedia(entry.uri);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(s.couldNotDelete)),
        );
      }
    }
    await widget.history.remove(entry);
  }

  void _showOptions(HistoryEntry entry) {
    final s = S.of(context);
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.play_arrow),
              title: Text(s.play),
              onTap: () {
                Navigator.pop(context);
                _play(entry);
              },
            ),
            ListTile(
              leading: const Icon(Icons.share),
              title: Text(s.share),
              onTap: () {
                Navigator.pop(context);
                widget.engine.share(entry.uri, entry.mime);
              },
            ),
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: Text(s.openWithApp),
              onTap: () {
                Navigator.pop(context);
                widget.engine.openWith(entry.uri, entry.mime);
              },
            ),
            if (entry.sourceUrl.isNotEmpty)
              ListTile(
                leading: const Icon(Icons.link),
                title: Text(s.viewOn(entry.network.label)),
                onTap: () {
                  Navigator.pop(context);
                  widget.engine.openUrl(entry.sourceUrl);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(s.delete),
              onTap: () {
                Navigator.pop(context);
                _delete(entry);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([widget.manager, widget.history]),
      builder: (context, _) {
        final s = S.of(context);
        final tasks = widget.manager.tasks;
        final entries = widget.history.entries.where((e) {
          switch (_filter) {
            case _Filter.all:
              return true;
            case _Filter.video:
              return !e.isAudio;
            case _Filter.audio:
              return e.isAudio;
          }
        }).toList();

        if (tasks.isEmpty && widget.history.entries.isEmpty) {
          return const _EmptyHistory();
        }

        return CustomScrollView(
          slivers: [
            if (tasks.isNotEmpty) ...[
              _header(context, s.downloadingCount(tasks.length)),
              SliverList.builder(
                itemCount: tasks.length,
                itemBuilder: (context, i) {
                  final task = tasks[i];
                  return TaskTile(
                    task: task,
                    manager: widget.manager,
                    onLogin: task.network.supportsLogin
                        ? () async {
                            final ok = await LoginScreen.open(context, task.network, widget.accounts);
                            if (ok) widget.manager.retry(task);
                          }
                        : null,
                  );
                },
              ),
            ],
            _header(context, s.downloaded),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Wrap(
                  spacing: 8,
                  children: [
                    for (final f in _Filter.values)
                      ChoiceChip(
                        label: Text(switch (f) {
                          _Filter.all => s.filterAll,
                          _Filter.video => s.filterVideos,
                          _Filter.audio => s.filterAudios,
                        }),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                  ],
                ),
              ),
            ),
            if (entries.isEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Center(child: Text(s.nothingYet)),
                ),
              )
            else
              SliverList.builder(
                itemCount: entries.length,
                itemBuilder: (context, i) => _entryTile(entries[i]),
              ),
            const SliverToBoxAdapter(child: SizedBox(height: 24)),
          ],
        );
      },
    );
  }

  Widget _header(BuildContext context, String text) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(text, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }

  Widget _entryTile(HistoryEntry entry) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: () => _play(entry),
      onLongPress: () => _showOptions(entry),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: SizedBox(
                width: 64,
                height: 80,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Thumbnail(network: entry.network, path: entry.thumbnailPath),
                    Center(
                      child: Icon(
                        entry.isAudio ? Icons.music_note : Icons.play_arrow,
                        color: Colors.white,
                        shadows: const [Shadow(blurRadius: 6)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      NetworkLogo(network: entry.network, size: 16),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          [
                            if (entry.author.isNotEmpty) entry.author,
                            entry.isAudio ? 'MP3' : 'Video',
                            formatDate(entry.createdAt),
                          ].join(' · '),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: S.of(context).options,
              icon: const Icon(Icons.more_vert),
              onPressed: () => _showOptions(entry),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Opacity(opacity: 0.85, child: AppLogo(size: 88)),
            const SizedBox(height: 12),
            Text(S.of(context).emptyHistory, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
