import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../workshop/work_order_detail_screen.dart';
import 'overview_repository.dart';

/// Dashboard operativo del día (toda la empresa): ventas de hoy, OTs y motos
/// en taller, citas, stock, ranking de servicios del mes y OTs recientes.
/// Las gráficas comparativas viven en Reportes → Análisis.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(dashboardOverviewProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dashboard')),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(dashboardOverviewProvider.future),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 80),
            Center(
                child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('$e', textAlign: TextAlign.center),
            )),
          ]),
          data: (o) => _Body(overview: o),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final DashboardOverview overview;
  const _Body({required this.overview});

  @override
  Widget build(BuildContext context) {
    final o = overview;
    final w = o.workshop;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── KPIs ────────────────────────────────────────────────
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.55,
          children: [
            if (o.sales != null)
              _Kpi(
                icon: Icons.point_of_sale,
                color: Colors.green,
                label: 'Ventas hoy',
                value: money(o.sales!.total),
                detail: '${o.sales!.count} ${o.sales!.count == 1 ? 'venta' : 'ventas'}',
              ),
            if (w != null) ...[
              _Kpi(
                icon: Icons.build_circle_outlined,
                color: Colors.deepPurple,
                label: 'OTs hoy',
                value: '${w.receivedToday}',
                detail: '${w.active} activas',
              ),
              _Kpi(
                icon: Icons.two_wheeler,
                color: Colors.orange,
                label: 'Motos en taller',
                value: '${w.vehiclesInShop}',
                detail: 'sin entregar',
              ),
              _Kpi(
                icon: Icons.calendar_month_outlined,
                color: Colors.pink,
                label: 'Citas hoy',
                value: '${w.appointments.total}',
                detail: '${w.appointments.pending} pendientes',
              ),
            ],
            if (o.stock != null)
              _Kpi(
                icon: Icons.inventory_2_outlined,
                color: Colors.indigo,
                label: 'Repuestos en stock',
                value: '${o.stock!.inStock}',
                detail: o.stock!.lowStock > 0
                    ? '${o.stock!.lowStock} en stock bajo'
                    : 'sin alertas',
                detailColor: o.stock!.lowStock > 0 ? Colors.red : null,
              ),
          ],
        ),

        if (w != null) ...[
          const SizedBox(height: 16),
          _StatusStrip(byStatus: w.byStatus),
          const SizedBox(height: 12),
          _NextAppointmentCard(appt: w.appointments.next),
          const SizedBox(height: 12),
          _TopServicesCard(services: w.topServices),
          const SizedBox(height: 12),
          _RecentOrdersCard(orders: w.recent),
        ],

        if (o.sales == null && w == null && o.stock == null)
          const Padding(
            padding: EdgeInsets.only(top: 80),
            child: Center(
                child: Text('No hay indicadores disponibles para tu usuario.')),
          ),
        const SizedBox(height: 24),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Widgets
// ═══════════════════════════════════════════════════════════════════

class _Kpi extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String detail;
  final Color? detailColor;

  const _Kpi({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.detail,
    this.detailColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 14,
                  backgroundColor: color.withValues(alpha: .12),
                  child: Icon(icon, color: color, size: 16),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      style: const TextStyle(fontSize: 12, color: Colors.black54),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ),
              ],
            ),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(value,
                  style: const TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
            ),
            Text(detail,
                style: TextStyle(
                    fontSize: 11,
                    color: detailColor ?? Colors.black45,
                    fontWeight: detailColor != null ? FontWeight.w600 : null),
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }
}

/// OTs activas por estado.
class _StatusStrip extends StatelessWidget {
  final Map<String, int> byStatus;
  const _StatusStrip({required this.byStatus});

  static const _meta = [
    ('recibida', 'Recibidas', Colors.blueGrey),
    ('diagnosticada', 'Diagnosticadas', Colors.indigo),
    ('en_proceso', 'En proceso', Colors.orange),
    ('terminada', 'Terminadas', Colors.green),
  ];

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('OTs en taller por estado',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final (key, label, color) in _meta)
                  Expanded(
                    child: Column(
                      children: [
                        Text('${byStatus[key] ?? 0}',
                            style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w800,
                                color: color)),
                        Text(label,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 10, color: Colors.black54)),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NextAppointmentCard extends StatelessWidget {
  final NextAppointment? appt;
  const _NextAppointmentCard({required this.appt});

  @override
  Widget build(BuildContext context) {
    final a = appt;
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Colors.pink.withValues(alpha: .12),
          child: const Icon(Icons.event_available, color: Colors.pink),
        ),
        title: Text(a == null ? 'Sin citas pendientes hoy' : 'Próxima cita',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: a == null
            ? null
            : Text([
                if (a.client != null && a.client!.isNotEmpty) a.client!,
                if (a.title != null && a.title!.isNotEmpty) a.title!,
              ].join('  ·  ')),
        trailing: a?.time == null
            ? null
            : Text(a!.time!,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800)),
      ),
    );
  }
}

/// Ranking de servicios por ingreso en el mes.
class _TopServicesCard extends StatelessWidget {
  final List<ServiceSale> services;
  const _TopServicesCard({required this.services});

  @override
  Widget build(BuildContext context) {
    final max = services.isEmpty
        ? 1.0
        : services.map((s) => s.amount).reduce((a, b) => a > b ? a : b);
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.handyman_outlined, size: 18, color: Colors.black54),
                SizedBox(width: 6),
                Text('Ventas por servicio',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                Spacer(),
                Text('este mes',
                    style: TextStyle(fontSize: 11, color: Colors.black45)),
              ],
            ),
            const SizedBox(height: 10),
            if (services.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Aún no hay servicios facturados este mes.',
                    style: TextStyle(color: Colors.black54)),
              )
            else
              for (final s in services) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(s.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                    const SizedBox(width: 8),
                    Text('×${s.count}',
                        style: const TextStyle(
                            fontSize: 11, color: Colors.black45)),
                    const SizedBox(width: 10),
                    Text(money(s.amount),
                        style: const TextStyle(fontWeight: FontWeight.w700)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: max > 0 ? (s.amount / max).clamp(0, 1).toDouble() : 0,
                    minHeight: 6,
                    backgroundColor: primary.withValues(alpha: .10),
                    color: primary,
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}

/// Últimas OTs, con acceso a su detalle.
class _RecentOrdersCard extends StatelessWidget {
  final List<WorkOrder> orders;
  const _RecentOrdersCard({required this.orders});

  static Color _statusColor(String status) => switch (status) {
        'recibida' => Colors.blueGrey,
        'diagnosticada' => Colors.indigo,
        'en_proceso' => Colors.orange,
        'terminada' => Colors.green,
        'entregada' => Colors.grey,
        _ => Colors.black45,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(14, 12, 14, 4),
            child: Text('OTs recientes',
                style: TextStyle(fontWeight: FontWeight.w700)),
          ),
          if (orders.isEmpty)
            const Padding(
              padding: EdgeInsets.fromLTRB(14, 8, 14, 16),
              child: Text('Sin órdenes registradas.',
                  style: TextStyle(color: Colors.black54)),
            )
          else
            for (final o in orders)
              ListTile(
                dense: true,
                title: Text(o.code,
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                subtitle: Text(
                  [o.client ?? 'Sin cliente', ?o.vehicle].join('  ·  '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(o.statusLabel,
                        style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _statusColor(o.status))),
                    Text(money(o.total),
                        style: const TextStyle(fontSize: 12)),
                  ],
                ),
                onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => WorkOrderDetailScreen(orderId: o.id),
                )),
              ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}
