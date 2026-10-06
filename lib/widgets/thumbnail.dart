import 'dart:io';

import 'package:flutter/material.dart';

import '../models/social_network.dart';
import 'network_logo.dart';

/// Miniatura desde internet o desde un archivo local. Si falla, muestra el logo de la red.
class Thumbnail extends StatelessWidget {
  const Thumbnail({
    super.key,
    required this.network,
    this.url,
    this.path,
    this.fit = BoxFit.cover,
  });

  final SocialNetwork network;
  final String? url;
  final String? path;
  final BoxFit fit;

  @override
  Widget build(BuildContext context) {
    Widget fallback(BuildContext context, Object error, StackTrace? stack) => _Placeholder(network: network);

    if (path != null) {
      return Image.file(File(path!), fit: fit, errorBuilder: fallback);
    }
    if (url != null && url!.isNotEmpty) {
      return Image.network(
        url!,
        fit: fit,
        headers: const {'User-Agent': 'Mozilla/5.0 (Linux; Android 14)'},
        errorBuilder: fallback,
        loadingBuilder: (context, child, progress) =>
            progress == null ? child : ColoredBox(color: Theme.of(context).colorScheme.surfaceContainerHighest),
      );
    }
    return _Placeholder(network: network);
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder({required this.network});

  final SocialNetwork network;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: Center(child: NetworkLogo(network: network, size: 36)),
    );
  }
}
