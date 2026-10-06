import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/download.dart';
import '../services/download_manager.dart';
import '../utils/format_utils.dart';
import 'thumbnail.dart';

/// Fila de una descarga en curso, en cola o fallida.
class TaskTile extends StatelessWidget {
  const TaskTile({super.key, required this.task, required this.manager, this.onLogin});

  final DownloadTask task;
  final DownloadManager manager;

  /// Si la red pidió iniciar sesión, muestra un botón para conectar la cuenta.
  final VoidCallback? onLogin;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final failed = task.state == TaskState.failed;

    final String status;
    switch (task.state) {
      case TaskState.queued:
        status = s.waiting;
      case TaskState.running:
        if (task.processing) {
          status = task.option.isAudio ? s.convertingMp3 : s.merging;
        } else if (task.progress == null) {
          status = s.connecting;
        } else {
          final pct = (task.progress! * 100).toStringAsFixed(0);
          final eta = task.etaSeconds != null && task.etaSeconds! > 0 ? s.timeLeft(formatDuration(task.etaSeconds)) : '';
          status = '$pct%$eta';
        }
      case TaskState.saving:
        status = s.savingToGallery;
      case TaskState.failed:
        status = task.error ?? s.error;
      case TaskState.canceled:
        status = s.canceling;
    }

    final showBar = task.state == TaskState.running || task.state == TaskState.saving || task.state == TaskState.queued;
    final determinate = task.state == TaskState.running && !task.processing ? task.progress : null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: SizedBox(
              width: 56,
              height: 72,
              child: Thumbnail(network: task.network, url: task.thumbnail),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(task.option.label, style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 6),
                if (showBar) ...[
                  LinearProgressIndicator(
                    value: task.state == TaskState.queued ? 0 : determinate,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  const SizedBox(height: 4),
                ],
                Text(
                  status,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(color: failed ? scheme.error : null),
                ),
                if (failed)
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton.icon(
                        onPressed: () => manager.retry(task),
                        icon: const Icon(Icons.refresh),
                        label: Text(s.retry),
                      ),
                      if (task.needsLogin && onLogin != null)
                        TextButton.icon(
                          onPressed: onLogin,
                          icon: const Icon(Icons.login),
                          label: Text(s.connectAccount),
                        ),
                    ],
                  ),
              ],
            ),
          ),
          IconButton(
            tooltip: failed ? s.remove : s.cancel,
            onPressed: task.state == TaskState.saving
                ? null
                : () => failed ? manager.dismiss(task) : manager.cancel(task),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
    );
  }
}
