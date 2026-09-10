import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

/// Ajustes: hub de configuración con recuadros. Cada recuadro lleva a la
/// pantalla que antes colgaba del menú lateral. Pensado para crecer.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider).me;

    if (me == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final tiles = <Widget>[
      if (me.can('company-profile.view'))
        _SettingTile(
          icon: Icons.business_outlined,
          label: 'Mi empresa',
          color: Colors.indigo,
          onTap: () => context.push('/company-profile'),
        ),
      if (me.planAllows('cash') && me.can('cash-registers.view'))
        _SettingTile(
          icon: Icons.point_of_sale_outlined,
          label: 'Cajas',
          color: Colors.teal,
          onTap: () => context.push('/cash-registers'),
        ),
      if (me.can('branches.view'))
        _SettingTile(
          icon: Icons.storefront_outlined,
          label: 'Sucursales',
          color: Colors.deepOrange,
          onTap: () => context.push('/branches'),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: tiles.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hay opciones de configuración disponibles para tu usuario.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            )
          : GridView.count(
              padding: const EdgeInsets.all(16),
              crossAxisCount: 2,
              shrinkWrap: true,
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: tiles,
            ),
    );
  }
}

/// Recuadro de Ajustes (mismo lenguaje visual que las acciones del inicio).
class _SettingTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundColor: color.withValues(alpha: .12),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(height: 10),
            Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
