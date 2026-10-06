/// 2970000 -> "2.97M", 15300 -> "15.3K".
String formatCount(int? value) {
  if (value == null) return '';
  if (value >= 1000000000) return '${_trim(value / 1000000000)}B';
  if (value >= 1000000) return '${_trim(value / 1000000)}M';
  if (value >= 1000) return '${_trim(value / 1000)}K';
  return '$value';
}

String _trim(double v) {
  final fixed = v >= 100 ? v.toStringAsFixed(0) : v.toStringAsFixed(v >= 10 ? 1 : 2);
  return fixed.contains('.') ? fixed.replaceFirst(RegExp(r'\.?0+$'), '') : fixed;
}

/// 75 -> "1:15", 3725 -> "1:02:05".
String formatDuration(num? seconds) {
  if (seconds == null) return '';
  final total = seconds.round();
  final h = total ~/ 3600;
  final m = (total % 3600) ~/ 60;
  final s = (total % 60).toString().padLeft(2, '0');
  return h > 0 ? '$h:${m.toString().padLeft(2, '0')}:$s' : '$m:$s';
}

String formatPosition(Duration d) => formatDuration(d.inMilliseconds / 1000);

/// Fecha corta: "hoy 3:20 p. m.", "ayer", "12/03/2026".
String formatDate(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) {
    final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
    final minute = date.minute.toString().padLeft(2, '0');
    return 'Hoy $hour:$minute ${date.hour < 12 ? 'a. m.' : 'p. m.'}';
  }
  if (diff == 1) return 'Ayer';
  return '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}';
}

/// Saca el primer enlace de un texto ("Mira este video https://vt.tiktok.com/xyz/ #fyp").
String? extractUrl(String text) {
  final match = RegExp(r'https?://[^\s<>"]+').firstMatch(text);
  if (match == null) return null;
  return match.group(0)!.replaceFirst(RegExp(r'[).,;!?\]]+$'), '');
}

/// 48234567 -> "46 MB", 1288490188 -> "1.2 GB".
String formatBytes(int? bytes) {
  if (bytes == null || bytes <= 0) return '';
  const mb = 1024 * 1024;
  if (bytes >= 1024 * mb) return '${_trim(bytes / (1024 * mb))} GB';
  if (bytes >= 10 * mb) return '${(bytes / mb).round()} MB';
  if (bytes >= mb) return '${(bytes / mb).toStringAsFixed(1)} MB';
  return '${(bytes / 1024).round()} KB';
}
