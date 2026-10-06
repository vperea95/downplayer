import 'package:flutter/material.dart';

import '../models/social_network.dart';
import '../theme.dart';

/// Logo simple de cada red: un cuadro redondeado con su color y un ícono.
class NetworkLogo extends StatelessWidget {
  const NetworkLogo({super.key, required this.network, this.size = 48});

  final SocialNetwork network;
  final double size;

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(size * 0.28);
    final decoration = switch (network) {
      SocialNetwork.instagram => BoxDecoration(
          borderRadius: radius,
          gradient: const LinearGradient(
            colors: AppColors.instagramGradient,
            begin: Alignment.bottomLeft,
            end: Alignment.topRight,
          ),
        ),
      _ => BoxDecoration(borderRadius: radius, color: network.color),
    };
    final icon = switch (network) {
      SocialNetwork.tiktok => Icons.tiktok,
      SocialNetwork.facebook => Icons.facebook,
      SocialNetwork.instagram => Icons.camera_alt_outlined,
      SocialNetwork.youtube => Icons.play_arrow_rounded,
    };
    return Container(
      width: size,
      height: size,
      decoration: decoration,
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white, size: size * (network == SocialNetwork.youtube ? 0.7 : 0.58)),
    );
  }
}
