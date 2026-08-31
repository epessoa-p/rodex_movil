import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/providers.dart';
import 'dashboard_repository.dart';

/// Config de cada módulo: clave del config → módulo API, etiqueta, permiso, plan.
class _ModuleDef {
  final String key; // ventas | taller | compras
  final String api; // sales | workshop | purchases
  final String label;
  final String plan;
  final String permission;
  final Color color;
  const _ModuleDef(
      this.key, this.api, this.label, this.plan, this.permission, this.color);
}

const _defs = <_ModuleDef>[
  _ModuleDef('ventas', 'sales', 'Ventas', 'sales', 'sales-dashboard.view',
      Colors.green),
  _ModuleDef('taller', 'workshop', 'Taller', 'workshop',
      'workshop-dashboard.view', Colors.deepPurple),
  _ModuleDef('compras', 'purchases', 'Compras', 'purchases',
      'purchases-dashboard.view', Colors.brown),
];

/// ¿Qué módulos de dashboard puede ver el usuario, en el orden de su empresa?
List<_ModuleDef> _enabledDashboards(dynamic me) {
  if (me == null) return const [];
  final order = (me.company?.dashboardModules as List<String>?) ??
      ['ventas', 'taller', 'compras'];
  final result = <_ModuleDef>[];
  for (final key in order) {
    final def = _defs.where((d) => d.key == key);
    if (def.isEmpty) continue;
    final d = def.first;
    if (me.planAllows(d.plan) && me.can(d.permission)) result.add(d);
  }
  return result;
}

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider).me;
    final tabs = _enabledDashboards(me);

    if (tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        body: const Center(
            child: Padding(
          padding: EdgeInsets.all(24),
          child: Text('No tienes dashboards habilitados.',
              textAlign: TextAlign.center),
        )),
      );
    }

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Dashboard'),
          bottom: TabBar(
            isScrollable: tabs.length > 2,
            tabs: [for (final t in tabs) Tab(text: t.label)],
          ),
        ),
        body: TabBarView(
          children: [for (final t in tabs) _ModuleTab(def: t)],
        ),
      ),
    );
  }
}

class _ModuleTab extends ConsumerStatefulWidget {
  final _ModuleDef def;
  const _ModuleTab({required this.def});

  @override
  ConsumerState<_ModuleTab> createState() => _ModuleTabState();
}

class _ModuleTabState extends ConsumerState<_ModuleTab>
    with AutomaticKeepAliveClientMixin {
  bool _amount = true; // true = Monto, false = Cantidad

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final async = ref.watch(dashboardSeriesProvider(widget.def.api));

    return RefreshIndicator(
      onRefresh: () async =>
          ref.invalidate(dashboardSeriesProvider(widget.def.api)),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(children: [
          const SizedBox(height: 80),
          Center(child: Text('$e', textAlign: TextAlign.center)),
        ]),
        data: (s) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Monto')),
                ButtonSegment(value: false, label: Text('Cantidad')),
              ],
              selected: {_amount},
              onSelectionChanged: (v) => setState(() => _amount = v.first),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                    child: _kpi('Semana', s.weekly, widget.def.color)),
                const SizedBox(width: 10),
                Expanded(child: _kpi('Mes', s.monthly, widget.def.color)),
              ],
            ),
            const SizedBox(height: 20),
            _ChartCard(
              title: 'Comparativa semanal (últimas ${s.weekly.length})',
              points: s.weekly,
              amount: _amount,
              color: widget.def.color,
            ),
            const SizedBox(height: 16),
            _ChartCard(
              title: 'Comparativa mensual (últimos ${s.monthly.length})',
              points: s.monthly,
              amount: _amount,
              color: widget.def.color,
            ),
          ],
        ),
      ),
    );
  }

  Widget _kpi(String label, List<SeriesPoint> pts, Color color) {
    final cur = pts.isNotEmpty ? _val(pts.last) : 0.0;
    final prev = pts.length >= 2 ? _val(pts[pts.length - 2]) : 0.0;
    final delta = prev != 0 ? (cur - prev) / prev * 100 : (cur > 0 ? 100.0 : 0.0);
    final up = cur >= prev;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 12, color: Colors.black54)),
            const SizedBox(height: 2),
            Text(_amount ? money(cur) : cur.toInt().toString(),
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: color)),
            const SizedBox(height: 2),
            Row(
              children: [
                Icon(up ? Icons.trending_up : Icons.trending_down,
                    size: 15, color: up ? Colors.green : Colors.red),
                const SizedBox(width: 3),
                Text('${delta >= 0 ? '+' : ''}${delta.toStringAsFixed(0)}% vs anterior',
                    style: TextStyle(
                        fontSize: 11,
                        color: up ? Colors.green : Colors.red)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  double _val(SeriesPoint p) => _amount ? p.amount : p.count.toDouble();
}

class _ChartCard extends StatelessWidget {
  final String title;
  final List<SeriesPoint> points;
  final bool amount;
  final Color color;
  const _ChartCard(
      {required this.title,
      required this.points,
      required this.amount,
      required this.color});

  double _val(SeriesPoint p) => amount ? p.amount : p.count.toDouble();

  @override
  Widget build(BuildContext context) {
    final values = points.map(_val).toList();
    final maxV = values.isEmpty ? 1.0 : values.reduce((a, b) => a > b ? a : b);
    final maxY = maxV <= 0 ? 1.0 : maxV * 1.25;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 14, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title,
                style: const TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            SizedBox(
              height: 190,
              child: BarChart(
                BarChartData(
                  alignment: BarChartAlignment.spaceAround,
                  maxY: maxY,
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  titlesData: FlTitlesData(
                    leftTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    rightTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    topTitles: const AxisTitles(
                        sideTitles: SideTitles(showTitles: false)),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 22,
                        getTitlesWidget: (v, meta) {
                          final i = v.toInt();
                          if (i < 0 || i >= points.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(points[i].label,
                                style: const TextStyle(fontSize: 9)),
                          );
                        },
                      ),
                    ),
                  ),
                  barTouchData: BarTouchData(
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipItem: (group, gi, rod, ri) {
                        final p = points[group.x];
                        final txt = amount ? money(p.amount) : '${p.count}';
                        return BarTooltipItem(
                            txt, const TextStyle(color: Colors.white, fontSize: 11));
                      },
                    ),
                  ),
                  barGroups: [
                    for (int i = 0; i < points.length; i++)
                      BarChartGroupData(x: i, barRods: [
                        BarChartRodData(
                          toY: values[i],
                          color: color,
                          width: 14,
                          borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(4)),
                        ),
                      ]),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
