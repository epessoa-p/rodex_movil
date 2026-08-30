import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../pos/pos_repository.dart';
import '../workshop/workshop_repository.dart';
import 'app_drawer.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider).me;
    final session = ref.watch(cashSessionProvider);

    if (me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final canSell = me.planAllows('sales') &&
        me.canAny(['pos.access', 'sales.create']);
    final canWorkshop = me.planAllows('workshop') && me.can('workshop.view');

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(me.company?.name ?? 'Rodex'),
        actions: [
          IconButton(
            tooltip: 'Ajustes',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(cashSessionProvider);
          ref.invalidate(todaySummaryProvider);
          ref.invalidate(workOrdersSummaryProvider);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CashCard(session: session),
            if (canSell) ...[
              const SizedBox(height: 12),
              _DaySummaryCard(summary: ref.watch(todaySummaryProvider)),
            ],
            if (canWorkshop) ...[
              const SizedBox(height: 12),
              _WorkOrdersSummaryCard(
                  summary: ref.watch(workOrdersSummaryProvider)),
            ],
            const SizedBox(height: 20),
            Text('Acciones', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.3,
              children: [
                if (canSell)
                  _ActionTile(
                    icon: Icons.point_of_sale,
                    label: 'Nueva venta',
                    color: Colors.green,
                    onTap: () => context.push('/pos'),
                  ),
                if (me.planAllows('inventory') || me.can('products.view'))
                  _ActionTile(
                    icon: Icons.inventory_2_outlined,
                    label: 'Productos',
                    color: Colors.indigo,
                    onTap: () => context.push('/products'),
                  ),
                if (me.can('clients.view') || canSell)
                  _ActionTile(
                    icon: Icons.people_alt_outlined,
                    label: 'Clientes',
                    color: Colors.teal,
                    onTap: () => context.push('/clients'),
                  ),
                if (me.planAllows('workshop') && me.can('workshop.view'))
                  _ActionTile(
                    icon: Icons.build_circle_outlined,
                    label: 'Taller',
                    color: Colors.deepPurple,
                    onTap: () => context.push('/workshop'),
                  ),
                if (me.planAllows('workshop') && me.can('appointments.view'))
                  _ActionTile(
                    icon: Icons.calendar_month_outlined,
                    label: 'Agenda',
                    color: Colors.pink,
                    onTap: () => context.push('/agenda'),
                  ),
                if (me.planAllows('purchases') && me.can('purchases.create'))
                  _ActionTile(
                    icon: Icons.shopping_bag_outlined,
                    label: 'Compra directa',
                    color: Colors.brown,
                    onTap: () => context.push('/purchases/direct'),
                  ),
                if (me.planAllows('purchases') && me.can('treasury.view'))
                  _ActionTile(
                    icon: Icons.account_balance,
                    label: 'Tesorería',
                    color: Colors.teal,
                    onTap: () => context.push('/treasury'),
                  ),
                if (me.canAny(['cash.operate', 'pos.access']))
                  _ActionTile(
                    icon: Icons.savings_outlined,
                    label: 'Caja',
                    color: Colors.orange,
                    onTap: () => context.push('/cash'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _CashCard extends StatelessWidget {
  final AsyncValue<CashSession?> session;
  const _CashCard({required this.session});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: session.when(
          loading: () => const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Row(children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            Expanded(child: Text('$e')),
          ]),
          data: (s) => Row(
            children: [
              CircleAvatar(
                backgroundColor:
                    (s != null ? Colors.green : Colors.grey).withValues(alpha: .15),
                child: Icon(Icons.savings_outlined,
                    color: s != null ? Colors.green : Colors.grey),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(s != null ? 'Caja abierta' : 'Caja cerrada',
                        style:
                            const TextStyle(fontWeight: FontWeight.w700)),
                    Text(
                      s != null
                          ? '${s.cashRegister ?? ''} · ${s.branch ?? ''}  ·  Esperado ${money(s.expectedAmount)}'
                          : 'Abre tu caja para poder vender',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DaySummaryCard extends StatelessWidget {
  final AsyncValue<DaySummary> summary;
  const _DaySummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: summary.when(
          loading: () => const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Row(children: [
            const Icon(Icons.error_outline, color: Colors.red),
            const SizedBox(width: 8),
            const Expanded(child: Text('No se pudo cargar el resumen')),
          ]),
          data: (s) => Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.green.withValues(alpha: .15),
                child: const Icon(Icons.today_outlined, color: Colors.green),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.scope == 'all' ? 'Ventas de hoy' : 'Mis ventas de hoy',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${s.salesCount} ${s.salesCount == 1 ? 'venta' : 'ventas'}',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
              Text(money(s.salesTotal),
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _WorkOrdersSummaryCard extends StatelessWidget {
  final AsyncValue<WorkOrdersSummary> summary;
  const _WorkOrdersSummaryCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: summary.when(
          loading: () => const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator())),
          error: (e, _) => Row(children: const [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Expanded(child: Text('No se pudo cargar el resumen')),
          ]),
          data: (s) => Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.deepPurple.withValues(alpha: .15),
                child: const Icon(Icons.build_circle_outlined,
                    color: Colors.deepPurple),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.scope == 'all' ? 'OTs de hoy' : 'Mis OTs de hoy',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    Text(
                      '${s.receivedToday} ${s.receivedToday == 1 ? 'recibida' : 'recibidas'} · ${s.active} ${s.active == 1 ? 'activa' : 'activas'}',
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 13),
                    ),
                  ],
                ),
              ),
              Text('${s.active}',
                  style: const TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionTile({
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
