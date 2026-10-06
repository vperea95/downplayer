import 'package:flutter/material.dart';

import '../models/download.dart';
import '../models/social_network.dart';
import '../services/accounts_service.dart';
import '../services/download_manager.dart';
import '../services/engine.dart';
import '../services/history_service.dart';
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
  });

  final Engine engine;
  final DownloadManager manager;
  final HistoryService history;
  final AccountsService accounts;

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
    final url = extractUrl(text);
    if (url == null) {
      _snack('Lo que compartiste no tiene un enlace.');
      return;
    }
    final network = SocialNetwork.detect(url);
    if (network == null) {
      _snack('Ese enlace no es de TikTok, Facebook, Instagram ni YouTube.');
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
          initialUrl: initialUrl,
          onOpenHistory: () => setState(() => _tab = 1),
        ),
      ),
    );
  }

  void _onCompleted(HistoryEntry entry) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('Guardado en la galería: ${entry.title}', maxLines: 2, overflow: TextOverflow.ellipsis),
        action: SnackBarAction(
          label: 'Ver',
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
    Navigator.pop(context); // cierra el menú lateral
    _snack('Buscando la versión más reciente del motor…');
    try {
      final updated = await widget.engine.update();
      _snack(updated
          ? 'Motor actualizado a la versión ${widget.engine.version ?? ''}.'
          : 'El motor ya está en la versión más reciente.');
    } on EngineException catch (e) {
      _snack('No se pudo actualizar: ${e.message}');
    }
  }

  Future<void> _toggleAccount(SocialNetwork network) async {
    Navigator.pop(context);
    if (widget.accounts.isConnected(network)) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('¿Desconectar ${network.label}?'),
          content: const Text('Algunos videos pueden dejar de descargarse.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Desconectar')),
          ],
        ),
      );
      if (confirm == true) await widget.accounts.disconnect(network);
      return;
    }
    final ok = await LoginScreen.open(context, network, widget.accounts);
    if (ok && mounted) _snack('Cuenta de ${network.label} conectada.');
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _tab == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _tab = 0);
      },
      child: Scaffold(
        appBar: AppBar(
          title: const AppTitle(),
          actions: [
            IconButton(
              tooltip: 'Abrir TikTok',
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
                const NavigationDestination(
                  icon: Icon(Icons.home_outlined),
                  selectedIcon: Icon(Icons.home),
                  label: 'Inicio',
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
                  label: 'Historial',
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
          listenable: Listenable.merge([widget.engine, widget.accounts]),
          builder: (context, _) {
            final engine = widget.engine;
            return ListView(
              children: [
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 20, 24, 4),
                  child: AppTitle(),
                ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 12),
                  child: Text('Descarga sin publicidad'),
                ),
                const Divider(),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 8, 24, 4),
                  child: Text('Cuentas (opcional)', style: TextStyle(fontWeight: FontWeight.w700)),
                ),
                for (final network in SocialNetwork.values.where((n) => n.supportsLogin))
                  ListTile(
                    leading: NetworkLogo(network: network, size: 32),
                    title: Text(network.label),
                    subtitle: Text(widget.accounts.isConnected(network) ? 'Conectada' : 'Sin conectar'),
                    trailing: Text(widget.accounts.isConnected(network) ? 'Salir' : 'Conectar'),
                    onTap: () => _toggleAccount(network),
                  ),
                const Padding(
                  padding: EdgeInsets.fromLTRB(24, 0, 24, 8),
                  child: Text(
                    'Solo hace falta si un video dice que pide iniciar sesión.',
                    style: TextStyle(fontSize: 12),
                  ),
                ),
                const Divider(),
                ListTile(
                  leading: engine.updating
                      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.system_update_alt),
                  title: const Text('Actualizar motor de descarga'),
                  subtitle: Text(engine.version != null ? 'Versión ${engine.version}' : 'Úsalo si las descargas fallan'),
                  onTap: engine.updating || engine.status != EngineStatus.ready ? null : _updateEngine,
                ),
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: const Text('Acerca de'),
                  onTap: () {
                    Navigator.pop(context);
                    showAboutDialog(
                      context: context,
                      applicationName: 'DownPlayer',
                      applicationVersion: '1.0.0',
                      children: const [
                        Text(
                          'Descarga videos y audio de TikTok, Facebook, Instagram y YouTube, sin publicidad. '
                          'Usa el motor libre yt-dlp. Descarga solo contenido que tengas derecho a guardar.',
                        ),
                      ],
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
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
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        ListenableBuilder(listenable: engine, builder: (context, _) => _EngineBanner(engine: engine)),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 12, 4, 4),
          child: Text('¿De dónde es el video?', style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 16),
          child: Text('Elige la red y pega el enlace.', style: theme.textTheme.bodyMedium),
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
            title: const Text('Más rápido'),
            subtitle: Text(
              'En TikTok, Facebook, Instagram o YouTube toca "Compartir" y elige DownPlayer. '
              'La app abre el video sola.',
              style: theme.textTheme.bodySmall,
            ),
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
                  SocialNetwork.tiktok => 'Sin marca de agua',
                  SocialNetwork.facebook => 'Videos y reels',
                  SocialNetwork.instagram => 'Reels y videos',
                  SocialNetwork.youtube => 'Videos, Shorts y MP3',
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
    final scheme = Theme.of(context).colorScheme;
    switch (engine.status) {
      case EngineStatus.ready:
        return const SizedBox.shrink();
      case EngineStatus.preparing:
        return Card(
          color: scheme.secondaryContainer,
          child: const ListTile(
            leading: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
            title: Text('Preparando el motor de descarga…'),
            subtitle: Text('La primera vez tarda unos segundos.'),
          ),
        );
      case EngineStatus.failed:
        return Card(
          color: scheme.errorContainer,
          child: ListTile(
            leading: const Icon(Icons.error_outline),
            title: const Text('El motor de descarga no arrancó'),
            subtitle: Text(engine.initError ?? ''),
            trailing: TextButton(onPressed: engine.init, child: const Text('Reintentar')),
          ),
        );
    }
  }
}
