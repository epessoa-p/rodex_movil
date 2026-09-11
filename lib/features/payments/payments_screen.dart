import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../workshop/mechanic_payments_screen.dart';
import 'expenses_tab.dart';
import 'personal_tab.dart';
import 'suppliers_payable_tab.dart';

/// Pagos: todas las salidas de dinero en una pantalla con tabs inferiores —
/// Mecánicos (comisiones), Proveedores (cuentas por pagar), Personal (sueldos)
/// y Gastos (servicios recurrentes y gastos libres). Cada tab se gatea por su
/// permiso; si solo queda uno visible, se muestra sin barra inferior.
class PaymentsScreen extends ConsumerStatefulWidget {
  const PaymentsScreen({super.key});

  @override
  ConsumerState<PaymentsScreen> createState() => _PaymentsScreenState();
}

class _Tab {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget body;
  const _Tab(this.label, this.icon, this.selectedIcon, this.body);
}

/// Permisos que habilitan cada tab (también los usa el drawer para "Pagos").
bool canPayMechanics(MeContext me) =>
    me.planAllows('workshop') && me.can('mechanic-payments.view');
bool canPaySuppliers(MeContext me) =>
    me.planAllows('purchases') && me.can('accounts-payable.view');
bool canPayPersonal(MeContext me) =>
    me.planAllows('cash') && me.can('cash.operate');
bool canPayExpenses(MeContext me) =>
    me.planAllows('cash') &&
    me.canAny(['cash.operate', 'expense-services.view']);
bool canSeePayments(MeContext me) =>
    canPayMechanics(me) ||
    canPaySuppliers(me) ||
    canPayPersonal(me) ||
    canPayExpenses(me);

class _PaymentsScreenState extends ConsumerState<PaymentsScreen> {
  int _index = 0;

  List<_Tab> _tabs(MeContext me) => [
    if (canPayMechanics(me))
      const _Tab(
        'Mecánicos',
        Icons.engineering_outlined,
        Icons.engineering,
        MechanicPaymentsTab(),
      ),
    if (canPaySuppliers(me))
      const _Tab(
        'Proveedores',
        Icons.storefront_outlined,
        Icons.storefront,
        SuppliersPayableTab(),
      ),
    if (canPayPersonal(me))
      const _Tab('Personal', Icons.badge_outlined, Icons.badge, PersonalTab()),
    if (canPayExpenses(me))
      const _Tab(
        'Gastos',
        Icons.receipt_long_outlined,
        Icons.receipt_long,
        ExpensesTab(),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).me;
    if (me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tabs = _tabs(me);
    if (tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Pagos')),
        body: const Center(child: Text('No tienes acceso a este módulo.')),
      );
    }
    final index = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      appBar: AppBar(title: const Text('Pagos')),
      body: IndexedStack(
        index: index,
        children: [for (final t in tabs) t.body],
      ),
      bottomNavigationBar: tabs.length < 2
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final t in tabs)
                  NavigationDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.selectedIcon),
                    label: t.label,
                  ),
              ],
            ),
    );
  }
}
