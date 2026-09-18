import 'package:flutter/material.dart';

/// Color distintivo de cada módulo/proceso. Única fuente de verdad: lo usan
/// los tiles del Home, los tabs de los hubs, los FAB y los recuadros de la OT,
/// así el mismo color acompaña al proceso en toda la app.
abstract final class ModuleColors {
  // Ventas / inventario
  static const sales = Colors.green;
  static const products = Colors.indigo;
  static final categories = Colors.orange.shade800;
  static const brands = Colors.purple;
  static const models = Colors.blueGrey;
  static final origins = Colors.cyan.shade700;

  // Taller
  static const workOrders = Colors.deepPurple;
  static const agenda = Colors.pink;
  static const services = Colors.teal;
  static const mechanics = Colors.blue;

  // Compras
  static const purchases = Colors.brown;
  static const purchaseOrders = Colors.deepOrange;
  static const suppliers = Colors.blueGrey;

  // Finanzas
  static const personal = Colors.blue;
  static final expenses = Colors.red.shade700;
  static const treasury = Colors.teal;

  // Clientes
  static final clients = Colors.cyan.shade800;
  static const vehicles = Colors.blueGrey;
  static final rentals = Colors.teal.shade700;

  /// Fondo suave (píldoras, indicadores, FAB tonal).
  static Color soft(Color c) => c.withValues(alpha: .14);

  /// Tono para texto/ícono sobre [soft]: el mismo color, algo más oscuro para
  /// que contraste en fondos claros.
  static Color onSoft(Color c) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness * .8).clamp(0.0, 1.0)).toColor();
  }
}
