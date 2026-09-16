import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../agenda/agenda_repository.dart';
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

    final canSell =
        me.planAllows('sales') && me.canAny(['pos.access', 'sales.create']);
    final canWorkshop = me.planAllows('workshop') && me.can('workshop.view');
    final canAgenda = me.planAllows('workshop') && me.can('appointments.view');
    final today = _todayIso();

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(me.company?.name ?? 'Rodex'),
        actions: [
          IconButton(
            tooltip: 'Perfil',
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: Theme.of(
                context,
              ).colorScheme.onPrimary.withValues(alpha: .20),
              child: Text(
                me.user.name.isNotEmpty ? me.user.name[0].toUpperCase() : '?',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
              ),
            ),
            onPressed: () => context.push('/profile'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(cashSessionProvider);
          ref.invalidate(todaySummaryProvider);
          ref.invalidate(workOrdersSummaryProvider);
          ref.invalidate(agendaDayProvider(today));
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _CashCard(
              session: session,
              onTap: me.canAny(['cash.operate', 'pos.access'])
                  ? () => context.push('/cash')
                  : null,
            ),
            // Ventas, OTs y Citas de hoy comparten UNA fila (las que apliquen
            // se reparten el ancho por igual).
            if (canSell || canWorkshop || canAgenda) ...[
              const SizedBox(height: 12),
              // IntrinsicHeight: el Row va dentro de un ListView (alto no
              // acotado), así las tarjetas quedan de la misma altura.
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: _spaced([
                    if (canSell)
                      _SalesMiniStat(
                        summary: ref.watch(todaySummaryProvider),
                        onTap: () => context.push('/sales'),
                      ),
                    if (canWorkshop)
                      _WorkOrdersMiniStat(
                        summary: ref.watch(workOrdersSummaryProvider),
                        onTap: () => context.push('/workshop'),
                      ),
                    if (canAgenda)
                      _AppointmentsMiniStat(
                        day: ref.watch(agendaDayProvider(today)),
                        onTap: () => context.push('/agenda'),
                      ),
                  ]),
                ),
              ),
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
  final VoidCallback? onTap;
  const _CashCard({required this.session, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: session.when(
            loading: () => const SizedBox(
              height: 48,
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.red),
                const SizedBox(width: 8),
                Expanded(child: Text('$e')),
              ],
            ),
            data: (s) => Row(
              children: [
                CircleAvatar(
                  backgroundColor: (s != null ? Colors.green : Colors.grey)
                      .withValues(alpha: .15),
                  child: Icon(
                    Icons.savings_outlined,
                    color: s != null ? Colors.green : Colors.grey,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s != null ? 'Caja abierta' : 'Caja cerrada',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        s != null
                            ? '${s.cashRegister ?? ''} · ${s.branch ?? ''}  ·  Esperado ${money(s.expectedAmount)}'
                            : 'Abre tu caja para poder vender',
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.outline,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Icon(
                    Icons.chevron_right,
                    color: Theme.of(context).colorScheme.outline,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "yyyy-mm-dd" de hoy (clave de `agendaDayProvider`).
String _todayIso() {
  final d = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

/// Tarjeta compacta para la fila "Ventas · OTs · Citas de hoy": ícono,
/// etiqueta, número grande y una sub-línea. Van en `Expanded` a partes iguales.
class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final AsyncValue<(String, String)> value; // (número grande, sub-línea)
  final VoidCallback? onTap;
  const _MiniStat({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final outline = Theme.of(context).colorScheme.outline;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              value.when(
                loading: () => const SizedBox(
                  height: 34,
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                ),
                error: (e, _) => const SizedBox(
                  height: 34,
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red, size: 16),
                      SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Sin datos',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                data: (v) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Encoge si no cabe (p. ej. "Bs 12.500" con 3 tarjetas).
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        v.$1,
                        maxLines: 1,
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    Text(
                      v.$2,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: outline, fontSize: 12),
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

/// Envuelve cada tarjeta en `Expanded` y las separa con 10 px.
List<Widget> _spaced(List<Widget> cards) => [
  for (var i = 0; i < cards.length; i++) ...[
    if (i > 0) const SizedBox(width: 10),
    Expanded(child: cards[i]),
  ],
];

class _SalesMiniStat extends StatelessWidget {
  final AsyncValue<DaySummary> summary;
  final VoidCallback? onTap;
  const _SalesMiniStat({required this.summary, this.onTap});

  @override
  Widget build(BuildContext context) {
    return _MiniStat(
      icon: Icons.point_of_sale,
      color: Colors.green,
      label: summary.valueOrNull?.scope == 'all' ? 'Ventas hoy' : 'Mis ventas',
      onTap: onTap,
      value: summary.whenData(
        (s) => (
          money(s.salesTotal),
          '${s.salesCount} ${s.salesCount == 1 ? 'venta' : 'ventas'}',
        ),
      ),
    );
  }
}

class _WorkOrdersMiniStat extends StatelessWidget {
  final AsyncValue<WorkOrdersSummary> summary;
  final VoidCallback? onTap;
  const _WorkOrdersMiniStat({required this.summary, this.onTap});

  @override
  Widget build(BuildContext context) {
    return _MiniStat(
      icon: Icons.build_circle_outlined,
      color: Colors.deepPurple,
      label: summary.valueOrNull?.scope == 'all' ? 'OTs hoy' : 'Mis OTs',
      onTap: onTap,
      // Grande: recibidas hoy; sub-línea corta (cabe en un tercio del ancho).
      value: summary.whenData(
        (s) => (
          '${s.receivedToday}',
          '${s.receivedToday == 1 ? 'recibida' : 'recibidas'} · ${s.active} act.',
        ),
      ),
    );
  }
}

class _AppointmentsMiniStat extends StatelessWidget {
  final AsyncValue<AgendaDay> day;
  final VoidCallback? onTap;
  const _AppointmentsMiniStat({required this.day, this.onTap});

  @override
  Widget build(BuildContext context) {
    return _MiniStat(
      icon: Icons.calendar_month_outlined,
      color: Colors.pink,
      label: 'Citas hoy',
      onTap: onTap,
      value: day.whenData((d) {
        final pending = d.programada + d.confirmada;
        return (
          '${d.total}',
          d.total == 0
              ? 'sin citas'
              : '$pending ${pending == 1 ? 'pendiente' : 'pendientes'}',
        );
      }),
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
