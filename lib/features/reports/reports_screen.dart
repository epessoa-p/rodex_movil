import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';

/// Reportes: hub de recuadros (mismo patrón que Ajustes). Agrupa las vistas de
/// análisis, que no son operación del día.
class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider).me;
    if (me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final canAnalytics =
        (me.planAllows('sales') && me.can('sales-dashboard.view')) ||
            (me.planAllows('workshop') && me.can('workshop-dashboard.view')) ||
            (me.planAllows('purchases') && me.can('purchases-dashboard.view'));

    final tiles = <Widget>[
      if (canAnalytics)
        _ReportTile(
          icon: Icons.insights_outlined,
          label: 'Análisis',
          color: Colors.indigo,
          onTap: () => context.push('/reports/analytics'),
        ),
      if (me.can('income-statement.view'))
        _ReportTile(
          icon: Icons.assessment_outlined,
          label: 'Estado de resultados',
          color: Colors.green,
          onTap: () => context.push('/income-statement'),
        ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Reportes')),
      body: tiles.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'No hay reportes disponibles para tu usuario.',
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

class _ReportTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ReportTile({
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
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
            ),
          ],
        ),
      ),
    );
  }
}
