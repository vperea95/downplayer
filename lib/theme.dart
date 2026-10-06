import 'package:flutter/material.dart';

/// Colores de la marca DownPlayer.
class AppColors {
  static const brand = Color(0xFFFE2C55);
  static const cyan = Color(0xFF25F4EE);
  static const instagramGradient = [Color(0xFFFEDA75), Color(0xFFFA7E1E), Color(0xFFD62976), Color(0xFF962FBF)];
}

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: AppColors.brand,
    brightness: brightness,
  ).copyWith(primary: AppColors.brand, onPrimary: Colors.white);
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: const AppBarTheme(centerTitle: false),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
  );
}

/// Nombre de la app con el "Player" en el color de la marca.
class AppTitle extends StatelessWidget {
  const AppTitle({super.key});

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800);
    return Text.rich(
      TextSpan(
        style: base,
        children: const [
          TextSpan(text: 'Down'),
          TextSpan(text: 'Player', style: TextStyle(color: AppColors.brand)),
        ],
      ),
    );
  }
}
