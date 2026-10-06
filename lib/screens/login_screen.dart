import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../l10n/strings.dart';
import '../models/social_network.dart';
import '../services/accounts_service.dart';

/// Abre la página oficial de Instagram o Facebook para iniciar sesión.
/// DownPlayer nunca ve la contraseña: solo usa la sesión que queda abierta.
/// Devuelve true si la cuenta quedó conectada.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, required this.network, required this.accounts});

  final SocialNetwork network;
  final AccountsService accounts;

  static Future<bool> open(BuildContext context, SocialNetwork network, AccountsService accounts) async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => LoginScreen(network: network, accounts: accounts)),
    );
    return ok ?? false;
  }

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final WebViewController _controller;
  bool _loading = true;
  bool _checking = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (!mounted) return;
            setState(() => _loading = false);
            _check(silent: true);
          },
        ),
      )
      ..loadRequest(Uri.parse(widget.network.loginUrl!));
  }

  /// Revisa si ya hay sesión. Si la hay, cierra la pantalla.
  Future<void> _check({bool silent = false}) async {
    if (_checking) return;
    _checking = true;
    final ok = await widget.accounts.refresh(widget.network);
    _checking = false;
    if (!mounted) return;
    if (ok) {
      Navigator.pop(context, true);
    } else if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).notLoggedYet)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(s.connectNetwork(widget.network.label)),
        actions: [
          TextButton(onPressed: () => _check(), child: Text(s.done)),
        ],
        bottom: _loading
            ? const PreferredSize(preferredSize: Size.fromHeight(3), child: LinearProgressIndicator(minHeight: 3))
            : null,
      ),
      body: Column(
        children: [
          MaterialBanner(
            content: Text(s.loginBanner(widget.network.label)),
            leading: const Icon(Icons.lock_outline),
            actions: const [SizedBox.shrink()],
          ),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
