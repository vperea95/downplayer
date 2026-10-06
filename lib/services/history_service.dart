import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/download.dart';

/// Lista de archivos descargados, guardada en el dispositivo (más reciente primero).
class HistoryService extends ChangeNotifier {
  static const _key = 'download_history';

  final List<HistoryEntry> _entries = [];
  SharedPreferences? _prefs;

  List<HistoryEntry> get entries => List.unmodifiable(_entries);

  Future<void> load() async {
    _prefs = await SharedPreferences.getInstance();
    _entries.clear();
    final raw = _prefs!.getString(_key);
    if (raw != null) {
      try {
        for (final item in jsonDecode(raw) as List) {
          final entry = HistoryEntry.fromJson(Map<String, dynamic>.from(item as Map));
          if (entry != null) _entries.add(entry);
        }
      } catch (e) {
        debugPrint('Historial dañado, se empieza de cero: $e');
      }
    }
    notifyListeners();
  }

  Future<void> add(HistoryEntry entry) async {
    _entries.insert(0, entry);
    notifyListeners();
    await _save();
  }

  Future<void> remove(HistoryEntry entry) async {
    _entries.removeWhere((e) => e.id == entry.id);
    notifyListeners();
    final thumb = entry.thumbnailPath;
    if (thumb != null) {
      try {
        await File(thumb).delete();
      } catch (_) {}
    }
    await _save();
  }

  Future<void> _save() async {
    await _prefs?.setString(_key, jsonEncode(_entries.map((e) => e.toJson()).toList()));
  }

  /// Guarda una copia de la miniatura, porque los enlaces de las redes caducan.
  Future<String?> cacheThumbnail(String? url, String id) async {
    if (url == null || url.isEmpty) return null;
    try {
      final response = await http
          .get(Uri.parse(url), headers: const {'User-Agent': 'Mozilla/5.0 (Linux; Android 14)'})
          .timeout(const Duration(seconds: 15));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
      final dir = Directory('${(await getApplicationSupportDirectory()).path}/miniaturas');
      await dir.create(recursive: true);
      final file = File('${dir.path}/$id.jpg');
      await file.writeAsBytes(response.bodyBytes);
      return file.path;
    } catch (_) {
      return null;
    }
  }
}
