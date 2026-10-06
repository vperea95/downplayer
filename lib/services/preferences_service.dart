import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/download.dart';

/// Preferencias del usuario guardadas en el dispositivo.
class PreferencesService extends ChangeNotifier {
  static const _qualityKey = 'preferred_quality';

  SharedPreferences? _prefs;

  /// Última calidad elegida: 0 = la mejor, -1 = solo audio, 720 = hasta 720p, etc.
  /// Null si todavía no ha elegido ninguna.
  int? _quality;

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _quality = _prefs!.getInt(_qualityKey);
    notifyListeners();
  }

  DownloadOption? get preferredOption {
    final q = _quality;
    if (q == null) return null;
    if (q < 0) return const DownloadOption.audio();
    return DownloadOption.video(maxHeight: q == 0 ? null : q);
  }

  Future<void> rememberOption(DownloadOption option) async {
    _quality = option.isAudio ? -1 : (option.maxHeight ?? 0);
    notifyListeners();
    await _prefs?.setInt(_qualityKey, _quality!);
  }
}
