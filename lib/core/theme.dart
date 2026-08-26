import 'package:flutter/material.dart';

/// Tema Material 3 de la app. Limpio y de uso simple.
/// Se puede tintar con el color de la empresa (theme_primary) más adelante.
class AppTheme {
  static ThemeData light([Color? seed]) {
    final scheme = ColorScheme.fromSeed(
      seedColor: seed ?? const Color(0xFF2E7D5B), // verde SCZ por defecto
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: const Color(0xFFF6F7F9),
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
        isDense: true,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.06)),
        ),
      ),
    );
  }

  /// Convierte un hex "#RRGGBB" (de la empresa) en Color, o null.
  static Color? colorFromHex(String? hex) {
    if (hex == null || !RegExp(r'^#?[0-9a-fA-F]{6}$').hasMatch(hex)) return null;
    final h = hex.replaceFirst('#', '');
    return Color(int.parse('FF$h', radix: 16));
  }
}
