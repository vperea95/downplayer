import 'package:flutter/material.dart';

/// Redes de las que se puede descargar. Cada una sabe reconocer sus enlaces.
enum SocialNetwork {
  tiktok(
    label: 'TikTok',
    color: Color(0xFF111111),
    hosts: ['tiktok.com'],
    example: 'https://vt.tiktok.com/...',
    appUrl: 'https://www.tiktok.com',
  ),
  facebook(
    label: 'Facebook',
    color: Color(0xFF1877F2),
    hosts: ['facebook.com', 'fb.watch', 'fb.com'],
    example: 'https://www.facebook.com/reel/...',
    appUrl: 'https://www.facebook.com',
    cookieDomain: 'facebook.com',
    sessionCookie: 'c_user',
    loginUrl: 'https://m.facebook.com/login',
  ),
  instagram(
    label: 'Instagram',
    color: Color(0xFFDD2A7B),
    hosts: ['instagram.com', 'instagr.am'],
    example: 'https://www.instagram.com/reel/...',
    appUrl: 'https://www.instagram.com',
    cookieDomain: 'instagram.com',
    sessionCookie: 'sessionid',
    loginUrl: 'https://www.instagram.com/accounts/login/',
  ),
  youtube(
    label: 'YouTube',
    color: Color(0xFFFF0000),
    hosts: ['youtube.com', 'youtu.be'],
    example: 'https://youtu.be/...',
    appUrl: 'https://www.youtube.com',
  );

  const SocialNetwork({
    required this.label,
    required this.color,
    required this.hosts,
    required this.example,
    required this.appUrl,
    this.cookieDomain,
    this.sessionCookie,
    this.loginUrl,
  });

  final String label;
  final Color color;
  final List<String> hosts;
  final String example;
  final String appUrl;

  /// Solo Instagram y Facebook permiten conectar una cuenta (algunos videos la piden).
  final String? cookieDomain;
  final String? sessionCookie;
  final String? loginUrl;

  bool get supportsLogin => cookieDomain != null;

  bool matches(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase() ?? '';
    return hosts.any((h) => host == h || host.endsWith('.$h'));
  }

  static SocialNetwork? detect(String url) {
    for (final network in values) {
      if (network.matches(url)) return network;
    }
    return null;
  }

  static SocialNetwork? byName(String name) {
    for (final network in values) {
      if (network.name == name) return network;
    }
    return null;
  }

  /// Enlaces que son un perfil, canal o lista (no un video): van directo a "Descarga por lotes".
  bool isCollectionUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    final path = uri.path;
    switch (this) {
      case SocialNetwork.tiktok:
        return RegExp(r'^/@[^/]+/?$').hasMatch(path);
      case SocialNetwork.youtube:
        if (uri.queryParameters.containsKey('v') || uri.host.contains('youtu.be')) return false;
        return path.startsWith('/playlist') ||
            path.startsWith('/@') ||
            path.startsWith('/channel/') ||
            path.startsWith('/c/');
      case SocialNetwork.facebook:
      case SocialNetwork.instagram:
        return false;
    }
  }
}
