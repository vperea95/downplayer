import 'package:flutter/material.dart';

import '../l10n/strings.dart';
import '../models/download.dart';
import '../models/social_network.dart';
import '../services/accounts_service.dart';
import '../services/download_manager.dart';
import '../services/engine.dart';
import '../services/history_service.dart';
import '../services/preferences_service.dart';
import '../theme.dart';
import '../utils/format_utils.dart';
import '../widgets/network_logo.dart';
import 'download_screen.dart';
import 'history_screen.dart';
import 'login_screen.dart';
import 'player_screen.dart';

/// Menú principal: el usuario elige de qué red es el enlace. Abajo, Inicio e Historial.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.engine,
    required this.manager,
    required this.history,
    required this.accounts,
    required this.preferences,
  });

  final Engine engine;
  final DownloadManager manager;
  final HistoryService history;
  final AccountsService accounts;
  final PreferencesService preferences;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    widget.engine.onSharedText = _openShared;
    widget.manager.onCompleted = _onCompleted;
    // Si la app se abrió con "Compartir -> DownPlayer".
    widget.engine.takeSharedText().then((text) {
      if (text != null && mounted) _openShared(text);
    }).catchError((_) {});
  }

  void _openShared(String text) {
    final s = S.of(context);
    final url = extractUrl(text);
    if (url == null) {
      _snack(s.sharedNoLink);
      return;
    }
    final network = SocialNetwork.detect(url);
    if (network == null) {
      _snack(s.sharedUnsupported);
      return;
    }
    Navigator.popUntil(context, (route) => route.isFirst);
    _openNetwork(network, initialUrl: url);
  }

  void _openNetwork(SocialNetwork network, {String? initialUrl}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DownloadScreen(
          network: network,
          engine: widget.engine,
          manager: widget.manager,
          accounts: widget.accounts,
          preferences: widget.preferences,
          initialUrl: initialUrl,
          onOpenHistory: () => setState(() => _tab = 1),
        ),
      ),
    );
  }

  void _onCompleted(HistoryEntry entry) {
    if (!mounted) return;
    final s = S.of(context);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(s.savedToGallery(entry.title), maxLines: 2, overflow: TextOverflow.ellipsis),
        action: SnackBarAction(
          label: s.view,
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => PlayerScreen(entry: entry, engine: widget.engine)),
          ),
        ),
      ));
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _updateEngine() async {
    final s = S.of(context);
    Navigator.pop(context); // cierra el menú lateral
    _snack(s.engineChecking);
    try {
      final updated = await widget.engine.update();
      if (!mounted) return;
      _snack(updated ? s.engineUpdated(widget.engine.version ?? '') : s.engineUpToDate);
    } on EngineException catch (e) {
      if (!mounted) return;
      _snack(s.engineUpdateFailed(e.message));
    }
  }

  Future<void> _toggleAccount(SocialNetwork network) async {
    final s = S.of(context);
    Navigator.pop(context);
    if (widget.accounts.isConnected(network)) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(s.disconnectTitle(network.label)),
          content: Text(s.disconnectBody),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.disconnect)),
          ],
        ),
      );
      if (confirm == true) await widget.accounts.disconnect(network);
      return;
    }
    final ok = await LoginScreen.open(context, network, widget.accounts);
    if (ok && mounted) _snack(s.accountConnected(network.label));
  }

  /// Diálogo con opciones; la elegida lleva un check.
  Future<T?> _pick<T>(String title, List<(T, String)> options, T current) {
    return showDialog<T>(
      context: context,
      builder: (context) => SimpleDialog(
        title: Text(title),
        children: [
          for (final (value, label) in options)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, value),
              child: Row(
                children: [
                  Expanded(child: Text(label)),
                  if (value == current) Icon(Icons.check, color: Theme.of(context).colorScheme.primary),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _themeLabel(S s, ThemeMode mode) => switch (mode) {
        ThemeMode.system => s.themeSystem,
        ThemeMode.light => s.themeLight,
        ThemeMode.dark => s.themeDark,
      };

  String _languageLabel(S s, String? code) => switch (code) {
        'es' => 'Español',
        'en' => 'English',
        _ => s.languageSystem,
      };

  Future<void> _chooseTheme() async {
    final s = S.of(context);
    final prefs = widget.preferences;
    final mode = await _pick<ThemeMode>(
      s.appearance,
      [for (final m in ThemeMode.values) (m, _themeLabel(s, m))],
      prefs.themeMode,
    );
    if (mode != null) await prefs.setThemeMode(mode);
  }

  Future<void> _chooseLanguage() async {
    final s = S.of(context);
    final prefs = widget.preferences;
    // '' representa "automático" porque showDialog devuelve null al cerrar sin elegir.
    final code = await _pick<String>(
      s.language,
      [('', s.languageSystem), ('es', 'Español'), ('en', 'English')],
      prefs.languageCode ?? '',
    );
    if (code != null) await prefs.setLanguage(code.isEmpty ? null : code);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        appBar: AppBar(
          titleSpacing: 0,
          title: const Row(
            children: [
              AppLogo(size: 32),
              SizedBox(width: 10),
              AppTitle(),
            ],
          ),
          actions: [
            IconButton(
              tooltip: s.openNetwork('TikTok'),
              onPressed: () => widget.engine.openUrl(SocialNetwork.tiktok.appUrl),
              icon: const NetworkLogo(network: SocialNetwork.tiktok, size: 32),
            ),
            const SizedBox(width: 8),
          ],
        ),
        drawer: _drawer(),
        body: IndexedStack(
          index: _tab,
          children: [
            _NetworkMenu(engine: widget.engine, onSelected: _openNetwork),
            HistoryScreen(
              engine: widget.engine,
              manager: widget.manager,
              history: widget.history,
              accounts: widget.accounts,
            ),
          ],
        ),
        bottomNavigationBar: ListenableBuilder(
          listenable: widget.manager,
          builder: (context, _) {
            final active = widget.manager.activeCount;
            return NavigationBar(
              selectedIndex: _tab,
              onDestinationSelected: (i) => setState(() => _tab = i),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.home_outlined),
                  selectedIcon: const Icon(Icons.home),
                  label: s.tabHome,
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: active > 0,
                    label: Text('$active'),
                    child: const Icon(Icons.download_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: active > 0,
                    label: Text('$active'),
                    child: const Icon(Icons.download),
                  ),
                  label: s.tabHistory,
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _drawer() {
    return Drawer(
      child: SafeArea(
        child: ListenableBuilder(
          listenable: Listenable.merge([widget.engine, widget.accounts, widget.preferences]),
          builder: (context, _) {
            final s = S.of(context);
            final engine = widget.engine;
            final prefs = widget.preferences;
            final muted = Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                );
            return ListView(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                  child: Row(
                    children: [
                      const AppLogo(size: 56),
                      const SizedBox(width: 14),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const AppTitle(),
                          Text(s.byVixago, style: muted),
                        ],
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Text(s.tagline),
                ),
                const Divider(),
                _sectionTitle(s.accountsOptional),
                for (final network in SocialNetwork.values.where((n) => n.supportsLogin))
                  ListTile(
                    leading: NetworkLogo(network: network, size: 32),
                    title: Text(network.label),
                    subtitle: Text(widget.accounts.isConnected(network) ? s.connected : s.notConnected),
                    trailing: Text(widget.accounts.isConnected(network) ? s.logout : s.connect),
                    onTap: () => _toggleAccount(network),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(s.accountsHint, style: const TextStyle(fontSize: 12)),
                ),
                const Divider(),
                _sectionTitle(s.settings),
                ListTile(
                  leading: const Icon(Icons.brightness_6_outlined),
                  title: Text(s.appearance),
                  subtitle: Text(_themeLabel(s, prefs.themeMode)),
                  onTap: _chooseTheme,
                ),
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(s.language),
                  subtitle: Text(_languageLabel(s, prefs.languageCode)),
                  onTap: _chooseLanguage,
                ),
                ListTile(
                  leading: engine.updating
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.system_update_alt),
                  title: Text(s.updateEngine),
                  subtitle: Text(engine.version != null ? s.engineVersion(engine.version!) : s.updateEngineHint),
                  onTap: engine.updating || engine.status != EngineStatus.ready ? null : _updateEngine,
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(s.about),
                  onTap: () {
                    Navigator.pop(context);
                    showAboutDialog(
                      context: context,
                      applicationName: 'DownPlayer',
                      applicationVersion: '1.2.0',
                      applicationIcon: const AppLogo(size: 56),
                      applicationLegalese: s.legalese,
                      children: [
                        const SizedBox(height: 16),
                        Text(s.aboutText),
                      ],
                    );
                  },
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
                  child: Text('DownPlayer 1.2.0 · ${s.byVixago}', style: muted),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: Text(text, style: const TextStyle(fontWeight: FontWeight.w700)),
    );
  }
}

/// Las cuatro redes en tarjetas grandes.
class _NetworkMenu extends StatelessWidget {
  const _NetworkMenu({required this.engine, required this.onSelected});

  final Engine engine;
  final void Function(SocialNetwork network) onSelected;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ListenableBuilder(listenable: engine, builder: (context, _) => _EngineBanner(engine: engine)),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
          child: Text(s.whereFrom, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Text(s.chooseNetwork, style: theme.textTheme.bodyMedium),
        ),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 600 ? 4 : 2;
            return GridView.count(
              crossAxisCount: columns,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1,
              children: [
                for (final network in SocialNetwork.values)
                  _NetworkCard(network: network, onTap: () => onSelected(network)),
              ],
            );
          },
        ),
        const SizedBox(height: 16),
        Card(
          child: ListTile(
            leading: const Icon(Icons.lightbulb_outline),
            title: Text(s.faster),
            subtitle: Text(s.fasterHint, style: theme.textTheme.bodySmall),
          ),
        ),
      ],
    );
  }
}

class _NetworkCard extends StatelessWidget {
  const _NetworkCard({required this.network, required this.onTap});

  final SocialNetwork network;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              NetworkLogo(network: network, size: 64),
              const SizedBox(height: 12),
              Text(network.label, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
              const SizedBox(height: 2),
              Text(
                switch (network) {
                  SocialNetwork.tiktok => s.tiktokTagline,
                  SocialNetwork.facebook => s.facebookTagline,
                  SocialNetwork.instagram => s.instagramTagline,
                  SocialNetwork.youtube => s.youtubeTagline,
                },
                style: theme.textTheme.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Aviso mientras el motor se prepara (solo tarda la primera vez) o si falló.
class _EngineBanner extends StatelessWidget {
  const _EngineBanner({required this.engine});

  final Engine engine;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    switch (engine.status) {
      case EngineStatus.ready:
        return const SizedBox.shrink();
      case EngineStatus.preparing:
        return Card(
          color: scheme.secondaryContainer,
          child: ListTile(
            leading: const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            title: Text(s.enginePreparing),
            subtitle: Text(s.enginePreparingHint),
          ),
        );
      case EngineStatus.failed:
        return Card(
          color: scheme.errorContainer,
          child: ListTile(
            leading: const Icon(Icons.error_outline),
            title: Text(s.engineFailed),
            subtitle: Text(engine.initError ?? ''),
            trailing: TextButton(onPressed: engine.init, child: Text(s.retry)),
          ),
        );
    }
  }
}
