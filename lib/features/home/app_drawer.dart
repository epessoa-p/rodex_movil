import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/providers.dart';
import '../payments/payments_screen.dart' show canSeePayments;

/// Menú lateral (Navigation Drawer) con los accesos de la app, gateados por
/// permiso/plan. Se abre con el botón de hamburguesa del inicio.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider).me;
    if (me == null) return const Drawer();

    final canSell =
        me.planAllows('sales') && me.canAny(['pos.access', 'sales.create']);
    final canDashboard =
        (me.planAllows('sales') && me.can('sales-dashboard.view')) ||
            (me.planAllows('workshop') && me.can('workshop-dashboard.view')) ||
            (me.planAllows('purchases') && me.can('purchases-dashboard.view'));
    final initial =
        me.user.name.isNotEmpty ? me.user.name[0].toUpperCase() : '?';

    return Drawer(
      child: SafeArea(
        child: Column(
          children: [
            // Encabezado con usuario + empresa
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 24,
                    child: Text(initial, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(me.user.name,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 15),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                        if (me.company != null)
                          Text(me.company!.name,
                              style: const TextStyle(
                                  color: Colors.black54, fontSize: 12),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  _item(context, Icons.insights_outlined, 'Dashboard',
                      '/dashboard',
                      show: canDashboard),
                  _item(context, Icons.receipt_long_outlined, 'Ventas',
                      '/sales',
                      show: me.planAllows('sales') &&
                          me.canAny(['sales.view', 'pos.access'])),
                  _item(context, Icons.inventory_2_outlined, 'Productos',
                      '/products',
                      show:
                          me.planAllows('inventory') || me.can('products.view')),
                  _item(context, Icons.people_alt_outlined, 'Clientes',
                      '/clients',
                      show: me.can('clients.view') || canSell),
                  _item(context, Icons.engineering_outlined, 'Mecánicos',
                      '/mechanics',
                      show: me.planAllows('workshop') &&
                          me.can('mechanics.view')),
                  // Pagos agrupa Mecánicos / Proveedores / Personal / Gastos.
                  _item(context, Icons.payments_outlined, 'Pagos', '/payments',
                      show: canSeePayments(me)),
                  // Compras agrupa los tabs Compras / OCs / Proveedores.
                  _item(context, Icons.shopping_bag_outlined, 'Compras',
                      '/purchases/receptions',
                      show: me.planAllows('purchases') &&
                          me.canAny([
                            'goods-receipts.create',
                            'goods-receipts.view',
                            'purchase-orders.view',
                            'purchases.view',
                            'purchases.create',
                            'suppliers.view',
                          ])),
                  _item(context, Icons.account_balance, 'Tesorería',
                      '/treasury',
                      show: me.planAllows('purchases') &&
                          me.can('treasury.view')),
                  const Divider(),
                  // Reportes agrupa Análisis (gráficas) y Estado de resultados.
                  _item(context, Icons.bar_chart_outlined, 'Reportes',
                      '/reports',
                      show: canDashboard || me.can('income-statement.view')),
                  // "Mi empresa" y "Cajas" viven ahora dentro de Ajustes.
                  _item(context, Icons.settings_outlined, 'Ajustes',
                      '/settings'),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.logout, color: Colors.red),
              title: const Text('Cerrar sesión',
                  style: TextStyle(color: Colors.red)),
              onTap: () => _logout(context, ref),
            ),
          ],
        ),
      ),
    );
  }

  Widget _item(BuildContext context, IconData icon, String label, String route,
      {bool show = true}) {
    if (!show) return const SizedBox.shrink();
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: () {
        Navigator.of(context).pop(); // cierra el drawer
        context.push(route);
      },
    );
  }

  Future<void> _logout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres salir de tu cuenta?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authControllerProvider.notifier).logout();
      // El router redirige a /login por el cambio de estado de sesión.
    }
  }
}
