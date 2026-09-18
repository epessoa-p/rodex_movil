import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/hub_nav_bar.dart';
import '../../core/models.dart';
import '../../core/module_colors.dart';
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

  List<HubTab> _tabs(MeContext me) => [
    if (canPayMechanics(me))
      HubTab(
        label: 'Mecánicos',
        icon: Icons.engineering_outlined,
        selectedIcon: Icons.engineering,
        color: ModuleColors.workOrders,
        build: () => const MechanicPaymentsTab(),
      ),
    if (canPaySuppliers(me))
      HubTab(
        label: 'Proveedores',
        icon: Icons.storefront_outlined,
        selectedIcon: Icons.storefront,
        color: ModuleColors.purchases,
        build: () => const SuppliersPayableTab(),
      ),
    if (canPayPersonal(me))
      HubTab(
        label: 'Personal',
        icon: Icons.badge_outlined,
        selectedIcon: Icons.badge,
        color: ModuleColors.personal,
        build: () => const PersonalTab(),
      ),
    if (canPayExpenses(me))
      HubTab(
        label: 'Gastos',
        icon: Icons.receipt_long_outlined,
        selectedIcon: Icons.receipt_long,
        color: ModuleColors.expenses,
        build: () => const ExpensesTab(),
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
        children: [for (final t in tabs) t.build()],
      ),
      bottomNavigationBar: tabs.length < 2
          ? null
          : HubNavBar(
              tabs: tabs,
              selectedIndex: index,
              onSelected: (i) => setState(() => _index = i),
            ),
    );
  }
}
