import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../l10n/strings.dart';
import '../models/download.dart';
import '../models/media_info.dart';
import '../models/social_network.dart';
import '../services/accounts_service.dart';
import '../services/download_manager.dart';
import '../services/engine.dart';
import '../services/preferences_service.dart';
import '../utils/format_utils.dart';
import '../widgets/network_logo.dart';
import '../widgets/quality_sheet.dart';
import '../widgets/task_tile.dart';
import '../widgets/thumbnail.dart';
import 'batch_screen.dart';
import 'login_screen.dart';

/// Pegar un enlace de una red, ver el video y elegir qué descargar.
class DownloadScreen extends StatefulWidget {
  const DownloadScreen({
    super.key,
    required this.network,
    required this.engine,
    required this.manager,
    required this.accounts,
    required this.preferences,
    this.initialUrl,
    this.onOpenHistory,
  });

  final SocialNetwork network;
  final Engine engine;
  final DownloadManager manager;
  final AccountsService accounts;
  final PreferencesService preferences;

  /// Enlace que llegó con "Compartir": se analiza apenas abre la pantalla.
  final String? initialUrl;
  final VoidCallback? onOpenHistory;

  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late SocialNetwork _network = widget.network;

  bool _loading = false;
  MediaInfo? _info;
  String? _error;
  bool _errorNeedsLogin = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    if (widget.initialUrl != null) {
      _controller.text = widget.initialUrl!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _analyze());
    } else {
      _pasteFromClipboard(onlyIfMatches: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// Al abrir, si en el portapapeles hay un enlace de esta red, se pega solo.
  Future<void> _pasteFromClipboard({bool onlyIfMatches = false}) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final url = extractUrl(data?.text ?? '');
    if (!mounted) return;
    if (url == null) {
      if (!onlyIfMatches) _snack(S.of(context).noLinkCopied);
      return;
    }
    if (onlyIfMatches && !_network.matches(url)) return;
    _controller.text = url;
  }

  Future<void> _analyze() async {
    FocusScope.of(context).unfocus();
    final url = extractUrl(_controller.text.trim());
    if (url == null) {
      _snack(S.of(context).pasteLinkOf(_network.label, _network.example));
      return;
    }
    if (url != _controller.text) _controller.text = url;

    // Si el enlace es de otra red, se cambia sola para que funcione.
    final detected = SocialNetwork.detect(url);
    if (detected != null && detected != _network) {
      setState(() => _network = detected);
      _snack(S.of(context).linkIsFrom(detected.label));
    }

    if (_network.isCollectionUrl(url)) {
      _openBatch(url, null);
      return;
    }

    if (widget.engine.status == EngineStatus.preparing) {
      _snack(S.of(context).enginePreparingWait);
    }

    setState(() {
      _loading = true;
      _error = null;
      _info = null;
    });
    try {
      final info = await widget.engine.getInfo(url, _network, cookies: widget.accounts.cookiesFor(_network));
      if (!mounted) return;
      setState(() => _info = info);
    } on EngineException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _errorNeedsLogin = e.needsLogin;
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _download(DownloadOption option) async {
    final info = _info;
    if (info == null) return;
    widget.manager.enqueue(
      network: _network,
      url: info.url,
      title: info.title,
      author: info.author,
      thumbnail: info.thumbnail,
      option: option,
    );
    final s = S.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(s.downloading(option.label)),
        action: widget.onOpenHistory == null
            ? null
            : SnackBarAction(
                label: s.view,
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                  widget.onOpenHistory!();
                },
              ),
      ));
  }

  Future<void> _chooseQuality() async {
    final info = _info;
    if (info == null) return;
    final option = await showQualitySheet(context, info, widget.preferences);
    if (option != null && mounted) await _download(option);
  }

  void _openBatch(String url, String? title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BatchScreen(
          network: _network,
          url: url,
          title: title,
          engine: widget.engine,
          manager: widget.manager,
          accounts: widget.accounts,
          preferences: widget.preferences,
        ),
      ),
    );
  }

  Future<void> _login() async {
    final ok = await LoginScreen.open(context, _network, widget.accounts);
    if (!mounted) return;
    if (ok) {
      _snack(S.of(context).accountConnected(_network.label));
      _analyze();
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            NetworkLogo(network: _network, size: 32),
            const SizedBox(width: 12),
            Text(_network.label),
          ],
        ),
        actions: [
          IconButton(
            tooltip: s.openNetwork(_network.label),
            icon: const Icon(Icons.open_in_new),
            onPressed: () => widget.engine.openUrl(_network.appUrl),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _linkBox(),
            const SizedBox(height: 16),
            if (_loading) _loadingCard(),
            if (_error != null) _errorCard(),
            if (_info != null) _mediaCard(_info!),
            if (_info == null && !_loading && _error == null) _howTo(),
          ],
        ),
      ),
    );
  }

  Widget _linkBox() {
    final s = S.of(context);
    final hasText = _controller.text.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                keyboardType: TextInputType.url,
                textInputAction: TextInputAction.go,
                onSubmitted: (_) => _analyze(),
                decoration: InputDecoration(
                  hintText: s.pasteHint(_network.label),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                  suffixIcon: hasText
                      ? IconButton(
                          tooltip: s.clear,
                          icon: const Icon(Icons.cancel),
                          onPressed: () {
                            _controller.clear();
                            setState(() {
                              _info = null;
                              _error = null;
                            });
                          },
                        )
                      : IconButton(
                          tooltip: s.paste,
                          icon: const Icon(Icons.content_paste),
                          onPressed: () => _pasteFromClipboard(),
                        ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              height: 56,
              child: FilledButton(
                onPressed: _loading ? null : _analyze,
                child: Text(s.download),
              ),
            ),
          ],
        ),
        if (!hasText)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _pasteFromClipboard(),
              icon: const Icon(Icons.content_paste, size: 18),
              label: Text(s.pasteCopied),
            ),
          ),
      ],
    );
  }

  Widget _loadingCard() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            Text(S.of(context).searchingVideo),
          ],
        ),
      ),
    );
  }

  Widget _errorCard() {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Card(
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.error_outline, color: scheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(s.couldNotGetVideo,
                      style: TextStyle(fontWeight: FontWeight.w700, color: scheme.onErrorContainer)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(_error!, style: TextStyle(color: scheme.onErrorContainer)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: _analyze,
                  icon: const Icon(Icons.refresh),
                  label: Text(s.retry),
                ),
                if (_network.supportsLogin && (_errorNeedsLogin || !widget.accounts.isConnected(_network)))
                  OutlinedButton.icon(
                    onPressed: _login,
                    icon: const Icon(Icons.login),
                    label: Text(s.connectNetwork(_network.label)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mediaCard(MediaInfo info) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final best = info.bestHeight;
    final videoLabel = best == null
        ? s.getVideo
        : best >= 1080
            ? s.getFullHd
            : best >= 720
                ? s.getHd
                : s.getVideo;

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AspectRatio(
            aspectRatio: 16 / 11,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Fondo desenfocado y la miniatura completa encima, como en las apps de video.
                Opacity(opacity: 0.35, child: Thumbnail(network: info.network, url: info.thumbnail)),
                ColoredBox(color: Colors.black.withValues(alpha: 0.4)),
                Thumbnail(network: info.network, url: info.thumbnail, fit: BoxFit.contain),
                if (info.viewCount != null)
                  Positioned(left: 10, top: 10, child: _chip(Icons.visibility, formatCount(info.viewCount))),
                if (info.duration != null)
                  Positioned(right: 10, top: 10, child: _chip(Icons.schedule, formatDuration(info.duration))),
                Positioned(left: 10, bottom: 10, child: NetworkLogo(network: info.network, size: 28)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (info.author.isNotEmpty)
                  Text(info.author, style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.primary)),
                Text(info.title, maxLines: 3, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyLarge),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            child: Row(
              children: [
                if (info.hasVideo)
                  _action(Icons.hd_outlined, videoLabel, _chooseQuality),
                _action(Icons.music_note_outlined, s.getAudio, () => _download(const DownloadOption.audio())),
                if (info.collectionUrl != null)
                  _action(Icons.collections_outlined, s.batchDownload,
                      () => _openBatch(info.collectionUrl!, info.author)),
              ],
            ),
          ),
          if (info.hasVideo)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: FilledButton.icon(
                onPressed: _chooseQuality,
                icon: const Icon(Icons.download),
                label: Text(best != null ? s.chooseQualityUpTo(qualityName(best)) : s.chooseQualityAndDownload),
              ),
            ),
          ListenableBuilder(
            listenable: widget.manager,
            builder: (context, _) {
              final tasks = widget.manager.tasksFor(info.url);
              if (tasks.isEmpty) return const SizedBox.shrink();
              return Column(
                children: [
                  const Divider(height: 1),
                  for (final task in tasks)
                    TaskTile(
                      task: task,
                      manager: widget.manager,
                      onLogin: _network.supportsLogin ? _login : null,
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _chip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: Colors.white),
          const SizedBox(width: 4),
          Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _action(IconData icon, String label, VoidCallback onTap) {
    return Expanded(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
          child: Column(
            children: [
              Icon(icon, size: 30),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _howTo() {
    final s = S.of(context);
    final theme = Theme.of(context);
    final steps = [s.howStep1(_network.label), s.howStep2, s.howStep3];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.howTo, style: theme.textTheme.titleMedium),
            const SizedBox(height: 12),
            for (var i = 0; i < steps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(radius: 12, child: Text('${i + 1}', style: const TextStyle(fontSize: 12))),
                    const SizedBox(width: 10),
                    Expanded(child: Text(steps[i])),
                  ],
                ),
              ),
            const SizedBox(height: 4),
            Text(
              s.shareTip(_network.label),
              style: theme.textTheme.bodySmall,
            ),
            if (_network == SocialNetwork.youtube || _network == SocialNetwork.tiktok) ...[
              const SizedBox(height: 4),
              Text(
                s.collectionTip,
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
