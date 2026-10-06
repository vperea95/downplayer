import 'dart:async';

import 'package:flutter/foundation.dart';

import '../l10n/strings.dart';
import '../models/download.dart';
import '../models/social_network.dart';
import 'accounts_service.dart';
import 'engine.dart';
import 'history_service.dart';

/// Cola de descargas: hasta [maxParallel] a la vez. Al terminar, el archivo se
/// guarda en la galería y pasa al historial.
class DownloadManager extends ChangeNotifier {
  DownloadManager({required this.engine, required this.history, required this.accounts});

  static const maxParallel = 2;

  final Engine engine;
  final HistoryService history;
  final AccountsService accounts;

  final List<DownloadTask> _tasks = [];
  int _counter = 0;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  /// Se llama cuando una descarga termina bien (para mostrar un aviso).
  void Function(HistoryEntry entry)? onCompleted;

  List<DownloadTask> get tasks => List.unmodifiable(_tasks);
  int get activeCount => _tasks.where((t) => t.isActive).length;

  List<DownloadTask> tasksFor(String url) => _tasks.where((t) => t.url == url).toList();

  DownloadTask enqueue({
    required SocialNetwork network,
    required String url,
    required String title,
    required String author,
    required String? thumbnail,
    required DownloadOption option,
  }) {
    final task = DownloadTask(
      id: '${DateTime.now().millisecondsSinceEpoch}_${_counter++}',
      network: network,
      url: url,
      title: title,
      author: author,
      thumbnail: thumbnail,
      option: option,
    );
    _tasks.insert(0, task);
    notifyListeners();
    _pump();
    return task;
  }

  Future<void> cancel(DownloadTask task) async {
    if (task.state == TaskState.queued) {
      task.state = TaskState.canceled;
      _tasks.remove(task);
      notifyListeners();
      return;
    }
    task.state = TaskState.canceled;
    notifyListeners();
    await engine.cancel(task.id);
  }

  void retry(DownloadTask task) {
    _tasks.remove(task);
    enqueue(
      network: task.network,
      url: task.url,
      title: task.title,
      author: task.author,
      thumbnail: task.thumbnail,
      option: task.option,
    );
  }

  void dismiss(DownloadTask task) {
    _tasks.remove(task);
    notifyListeners();
  }

  void _pump() {
    final running = _tasks.where((t) => t.state == TaskState.running || t.state == TaskState.saving).length;
    var free = maxParallel - running;
    // Las más antiguas primero (la lista está de más nueva a más antigua).
    for (final task in _tasks.reversed.toList()) {
      if (free <= 0) break;
      if (task.state != TaskState.queued) continue;
      free--;
      unawaited(_run(task));
    }
  }

  Future<void> _run(DownloadTask task) async {
    task
      ..state = TaskState.running
      ..progress = null
      ..error = null
      ..needsLogin = false;
    notifyListeners();

    try {
      final path = await engine.download(
        id: task.id,
        url: task.url,
        args: task.option.toArgs(),
        cookies: accounts.cookiesFor(task.network),
        onProgress: (progress, eta, line) {
          if (line.startsWith('[Merger]') || line.startsWith('[ExtractAudio]') || line.startsWith('[VideoConvertor]')) {
            task.processing = true;
          } else if (line.startsWith('[download]') && progress != null && progress < 1) {
            task.processing = false;
          }
          task
            ..progress = progress ?? task.progress
            ..etaSeconds = eta;
          _notifyThrottled();
        },
      );

      task
        ..state = TaskState.saving
        ..processing = false;
      notifyListeners();

      final uri = await engine.saveToGallery(path, audio: task.option.isAudio);
      final thumb = await history.cacheThumbnail(task.thumbnail, task.id);
      final entry = HistoryEntry(
        id: task.id,
        network: task.network,
        kind: task.option.kind,
        title: task.title,
        author: task.author,
        uri: uri,
        mime: _mimeFor(path, task.option.isAudio),
        sourceUrl: task.url,
        createdAt: DateTime.now(),
        thumbnailPath: thumb,
      );
      await history.add(entry);
      _tasks.remove(task);
      onCompleted?.call(entry);
    } on EngineException catch (e) {
      if (e.canceled || task.state == TaskState.canceled) {
        _tasks.remove(task);
      } else {
        task
          ..state = TaskState.failed
          ..error = e.message
          ..needsLogin = e.needsLogin;
      }
    } catch (e) {
      task
        ..state = TaskState.failed
        ..error = S.current.somethingWrong('$e');
    }
    notifyListeners();
    _pump();
  }

  void _notifyThrottled() {
    final now = DateTime.now();
    if (now.difference(_lastNotify) < const Duration(milliseconds: 250)) return;
    _lastNotify = now;
    notifyListeners();
  }

  static String _mimeFor(String path, bool audio) {
    final ext = path.split('.').last.toLowerCase();
    switch (ext) {
      case 'mp3':
        return 'audio/mpeg';
      case 'm4a':
        return 'audio/mp4';
      case 'webm':
        return audio ? 'audio/webm' : 'video/webm';
      case 'mkv':
        return 'video/x-matroska';
      case 'opus':
      case 'ogg':
        return 'audio/ogg';
      default:
        return audio ? 'audio/mp4' : 'video/mp4';
    }
  }
}
