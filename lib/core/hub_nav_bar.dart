import 'package:flutter/material.dart';

import 'module_colors.dart';

/// Tab de un hub (Taller, Inventario, Compras, Pagos): etiqueta, íconos,
/// **color distintivo** y constructor perezoso de su pantalla.
class HubTab {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Color color;
  final Widget Function() build;
  const HubTab({
    required this.label,
    required this.icon,
    required this.selectedIcon,
    required this.color,
    required this.build,
  });
}

/// Barra inferior de un hub donde cada tab tiene su color: el ícono de cada
/// destino va en su propio color (atenuado si no está activo), la píldora y
/// la etiqueta del activo toman ese color, y una franja de 3 px justo encima
/// de la barra cambia (animada) al color del tab. Así los tabs se reconocen
/// de un vistazo y el color acompaña al proceso (FAB, avatares).
class HubNavBar extends StatelessWidget {
  final List<HubTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  const HubNavBar({
    super.key,
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final active = tabs[selectedIndex.clamp(0, tabs.length - 1)].color;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [HubAccentBar(active), _bar(active)],
    );
  }

  Widget _bar(Color active) {
    return NavigationBarTheme(
      data: NavigationBarThemeData(
        indicatorColor: ModuleColors.soft(active),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            fontSize: 12,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
            color: states.contains(WidgetState.selected)
                ? ModuleColors.onSoft(active)
                : Colors.black54,
          ),
        ),
      ),
      child: NavigationBar(
        height: 68,
        selectedIndex: selectedIndex.clamp(0, tabs.length - 1),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: onSelected,
        destinations: [
          for (final t in tabs)
            NavigationDestination(
              icon: Icon(t.icon, color: t.color.withValues(alpha: .75)),
              selectedIcon: Icon(
                t.selectedIcon,
                color: ModuleColors.onSoft(t.color),
              ),
              label: t.label,
            ),
        ],
      ),
    );
  }
}

/// Franja de 3 px que toma el color del tab activo (animada). Va encima de
/// la barra de tabs (la pone [HubNavBar]).
class HubAccentBar extends StatelessWidget {
  final Color color;
  const HubAccentBar(this.color, {super.key});

  @override
  Widget build(BuildContext context) => AnimatedContainer(
    duration: const Duration(milliseconds: 220),
    height: 3,
    color: color,
  );
}
