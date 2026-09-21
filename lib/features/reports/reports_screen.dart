import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/module_colors.dart';
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

    final canFinance =
        me.can('income-statement.view') ||
        (me.planAllows('cash') && me.can('cash-registers.view'));
    final canAccounts =
        me.canAny(['cash-registers.view', 'sales.view', 'workshop.view']) ||
        (me.planAllows('purchases') &&
            me.canAny(['accounts-payable.view', 'purchases.view']));
    final canInventory = me.planAllows('inventory') && me.can('products.view');

    final tiles = <Widget>[
      if (canAnalytics)
        _ReportTile(
          icon: Icons.insights_outlined,
          label: 'Análisis',
          subtitle: 'Ventas, taller y compras',
          color: ModuleColors.dashboard,
          onTap: () => context.push('/reports/analytics'),
        ),
      if (canFinance)
        _ReportTile(
          icon: Icons.account_balance_wallet_outlined,
          label: 'Finanzas',
          subtitle: 'Resultados, movimientos y cierres',
          color: ModuleColors.sales,
          onTap: () => context.push('/reports/finance'),
        ),
      if (canAccounts)
        _ReportTile(
          icon: Icons.request_quote_outlined,
          label: 'Cuentas',
          subtitle: 'Por cobrar y por pagar',
          color: ModuleColors.payments,
          onTap: () => context.push('/reports/accounts'),
        ),
      if (canInventory)
        _ReportTile(
          icon: Icons.inventory_2_outlined,
          label: 'Inventario',
          subtitle: 'Valor a costo, a venta y stock bajo',
          color: ModuleColors.products,
          onTap: () => context.push('/reports/inventory'),
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
              childAspectRatio: 1.15,
              children: tiles,
            ),
    );
  }
}

class _ReportTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ReportTile({
    required this.icon,
    required this.label,
    this.subtitle,
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
              child: Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
                child: Text(
                  subtitle!,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
