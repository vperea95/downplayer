import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/social_network.dart';
import 'engine.dart';

/// Cuentas conectadas (Instagram y Facebook). Es opcional: solo sirve para los
/// videos que esas redes no muestran sin iniciar sesión.
class AccountsService extends ChangeNotifier {
  AccountsService(this._engine);

  static const _key = 'connected_accounts';

  final Engine _engine;
  final Set<String> _connected = {};
  SharedPreferences? _prefs;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _connected
      ..clear()
      ..addAll(_prefs!.getStringList(_key) ?? const []);
    notifyListeners();
  }

  bool isConnected(SocialNetwork network) => _connected.contains(network.name);

  /// Dominio de cookies que se le pasa a yt-dlp, o null si no hay cuenta conectada.
  String? cookiesFor(SocialNetwork network) => isConnected(network) ? network.cookieDomain : null;

  /// Se llama al volver de la pantalla de inicio de sesión. True si la sesión quedó abierta.
  Future<bool> refresh(SocialNetwork network) async {
    final ok = await _engine.saveCookies(network);
    if (ok) {
      _connected.add(network.name);
    } else {
      _connected.remove(network.name);
    }
    notifyListeners();
    await _prefs?.setStringList(_key, _connected.toList());
    return ok;
  }

  Future<void> disconnect(SocialNetwork network) async {
    await _engine.clearCookies(network);
    _connected.remove(network.name);
    notifyListeners();
    await _prefs?.setStringList(_key, _connected.toList());
  }
}
