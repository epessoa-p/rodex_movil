import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import 'profit_report_repository.dart';
import 'report_period.dart';

/// Ganancias: ventas y/o taller, precio − costo (y comisión del mecánico),
/// por hoy, semana, mes o rango.
class ProfitReportScreen extends ConsumerStatefulWidget {
  const ProfitReportScreen({super.key});

  @override
  ConsumerState<ProfitReportScreen> createState() => _ProfitReportScreenState();
}

class _ProfitReportScreenState extends ConsumerState<ProfitReportScreen> {
  ProfitQuery _q = ProfitQuery(period: ReportPeriod.of(ReportPreset.today));
  bool _showLow = false;

  void _set(ProfitQuery q) => setState(() => _q = q);

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(profitReportProvider(_q));
    final branches = async.valueOrNull?.branches ?? const [];

    return Scaffold(
      appBar: AppBar(title: const Text('Ganancias')),
      body: Column(
        children: [
          PeriodChips(
            period: _q.period,
            allowAll: false,
            onChanged: (p) => _set(_q.copyWith(period: p)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: SegmentedButton<ProfitScope>(
              showSelectedIcon: false,
              style: const ButtonStyle(visualDensity: VisualDensity.compact),
              segments: [
                for (final e in profitScopeLabels.entries)
                  ButtonSegment(
                    value: e.key,
                    label: Text(e.value),
                    icon: Icon(switch (e.key) {
                      ProfitScope.all => Icons.join_full,
                      ProfitScope.sales => Icons.shopping_cart_outlined,
                      ProfitScope.workshop => Icons.build_outlined,
                    }, size: 18),
                  ),
              ],
              selected: {_q.scope},
              onSelectionChanged: (s) => _set(_q.copyWith(scope: s.first)),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(profitReportProvider(_q)),
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  children: [
                    const SizedBox(height: 80),
                    Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text('$e', textAlign: TextAlign.center),
                    ),
                  ],
                ),
                data: (r) => ListView(
                  padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                  children: [
                    _filters(branches),
                    _ProfitHero(r: r),
                    const SizedBox(height: 8),
                    ..._notices(r),
                    if (r.salesEnabled) _salesCard(r),
                    if (r.workshopEnabled) _workshopCard(r),
                    _byDayCard(r),
                    _productsCard(r),
                    _transactionsCard(r),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filters(List branches) {
    final showMerge = _q.scope != ProfitScope.workshop;
    if (!showMerge && branches.length < 2) return const SizedBox(height: 8);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        children: [
          if (branches.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: DropdownButtonFormField<int?>(
                initialValue: _q.branchId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Sucursal',
                  isDense: true,
                  border: OutlineInputBorder(),
                ),
                items: [
                  const DropdownMenuItem<int?>(
                    value: null,
                    child: Text('Todas las sucursales'),
                  ),
                  for (final b in branches)
                    DropdownMenuItem<int?>(value: b.id, child: Text(b.name)),
                ],
                onChanged: (v) => _set(_q.copyWith(branchId: () => v)),
              ),
            ),
          if (showMerge)
            SwitchListTile(
              key: const Key('merge_quick'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 4),
              dense: true,
              title: const Text('Unir ventas rápidas'),
              subtitle: const Text(
                'Productos no cargados: no tienen costo conocido.',
                style: TextStyle(fontSize: 12),
              ),
              value: _q.mergeQuick,
              onChanged: (v) => _set(_q.copyWith(mergeQuick: v)),
            ),
        ],
      ),
    );
  }

  List<Widget> _notices(ProfitReport r) => [
    if (r.estimatedLines > 0)
      _Notice(
        color: Colors.orange,
        icon: Icons.info_outline,
        text:
            '${r.estimatedLines} ${r.estimatedLines == 1 ? 'línea es anterior' : 'líneas son anteriores'} '
            'a que se guardara el costo al vender: se usa el costo actual (ganancia estimada).',
      ),
    if (r.creditProfit > 0)
      _Notice(
        color: Colors.blue,
        icon: Icons.credit_card,
        text:
            '${money(r.creditProfit)} de la ganancia viene de '
            '${r.creditCount == 1 ? '1 venta u OT' : '${r.creditCount} ventas u OTs'} a crédito '
            '(se cuenta el día de la venta). '
            '${r.creditPending > 0 ? 'Quedan ${money(r.creditPending)} por cobrar.' : 'Ya están cobradas.'}',
      ),
    if (r.salesEnabled && r.quickCount > 0)
      _Notice(
        color: r.quickMerged ? Colors.orange : Colors.blueGrey,
        icon: Icons.bolt,
        text: r.quickMerged
            ? 'Incluye ${money(r.quickRevenue)} en ${r.quickCount} '
                  '${r.quickCount == 1 ? 'venta rápida' : 'ventas rápidas'} sin costo conocido: '
                  'el margen sale más alto de lo real.'
            : 'Aparte: ${money(r.quickRevenue)} en ${r.quickCount} '
                  '${r.quickCount == 1 ? 'venta rápida' : 'ventas rápidas'} (sin costo conocido). '
                  'No se suman a la ganancia.',
      ),
  ];

  Widget _salesCard(ProfitReport r) => _Section(
    icon: Icons.shopping_cart_outlined,
    color: Colors.blue,
    title: 'Ventas',
    trailing: '${r.salesCount} ${r.salesCount == 1 ? 'venta' : 'ventas'}',
    children: [
      _Line('Ingresos', money(r.salesRevenue)),
      if (r.interest > 0)
        _Line('Incluye intereses de crédito', '+ ${money(r.interest)}'),
      _Line('Costo de productos', '− ${money(r.salesCost)}', muted: true),
      if (r.returnsRevenue > 0)
        _Line(
          'Devoluciones (ya restadas)',
          money(r.returnsRevenue),
          muted: true,
        ),
      _ProfitLine(r.salesProfit, r.salesMargin),
    ],
  );

  Widget _workshopCard(ProfitReport r) => _Section(
    icon: Icons.build_outlined,
    color: Colors.orange,
    title: 'Taller',
    trailing:
        '${r.workshopCount} ${r.workshopCount == 1 ? 'OT entregada' : 'OTs entregadas'}',
    children: [
      _Line('Mano de obra', money(r.labor)),
      _Line('Repuestos', money(r.parts)),
      _Line('Costo de repuestos', '− ${money(r.partsCost)}', muted: true),
      if (r.commissionPaid > 0)
        _Line(
          'Comisión mecánicos (pagada)',
          '− ${money(r.commissionPaid)}',
          muted: true,
        ),
      if (r.commissionPending > 0)
        _Line(
          'Comisión mecánicos (por pagar)',
          '− ${money(r.commissionPending)}',
          muted: true,
        ),
      _ProfitLine(r.workshopProfit, r.workshopMargin),
    ],
  );

  Widget _byDayCard(ProfitReport r) => _Section(
    icon: Icons.calendar_month_outlined,
    color: Colors.blueGrey,
    title: 'Por día',
    children: [
      if (r.byDay.isEmpty)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Text(
            'Sin ventas ni OTs entregadas en el período.',
            style: TextStyle(color: Colors.black54),
          ),
        )
      else
        for (final d in r.byDay.reversed)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(
              children: [
                SizedBox(
                  width: 74,
                  child: Text(
                    _dayLabel(d.date),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Expanded(
                  child: Text(
                    'Vendido ${money(d.revenue)}',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  money(d.profit),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: d.profit < 0
                        ? Colors.red.shade700
                        : Colors.green.shade700,
                  ),
                ),
              ],
            ),
          ),
    ],
  );

  /// Ganancia de cada venta / OT. Si la lista es larga, se desplaza dentro
  /// del recuadro (alto máximo) sin alargar toda la pantalla.
  Widget _transactionsCard(ProfitReport r) {
    final tx = r.transactions;
    final title = switch (_q.scope) {
      ProfitScope.workshop => 'OTs entregadas',
      ProfitScope.sales => 'Ventas',
      ProfitScope.all => 'Ventas y OTs',
    };
    final countText = r.transactionsTotal > tx.length
        ? 'Las ${tx.length} más recientes de ${r.transactionsTotal}'
        : '${r.transactionsTotal} ${r.transactionsTotal == 1 ? 'registro' : 'registros'}';
    return _Section(
      icon: Icons.receipt_long_outlined,
      color: Colors.indigo,
      title: title,
      trailing: tx.isEmpty ? null : countText,
      children: [
        if (tx.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: Text(
              'Sin ventas ni OTs en el período.',
              style: TextStyle(color: Colors.black54),
            ),
          )
        else
          ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 380),
            child: ListView.separated(
              key: const Key('profit_transactions'),
              shrinkWrap: true,
              padding: EdgeInsets.zero,
              physics: const ClampingScrollPhysics(),
              itemCount: tx.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) => _TransactionRow(t: tx[i]),
            ),
          ),
      ],
    );
  }

  Widget _productsCard(ProfitReport r) {
    final rows = _showLow ? r.lowMargin : r.topProducts;
    return _Section(
      icon: Icons.emoji_events_outlined,
      color: Colors.amber.shade800,
      title: 'Productos',
      children: [
        SegmentedButton<bool>(
          showSelectedIcon: false,
          style: const ButtonStyle(visualDensity: VisualDensity.compact),
          segments: const [
            ButtonSegment(value: false, label: Text('Más ganancia')),
            ButtonSegment(value: true, label: Text('Margen bajo')),
          ],
          selected: {_showLow},
          onSelectionChanged: (s) => setState(() => _showLow = s.first),
        ),
        const SizedBox(height: 6),
        if (rows.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              _showLow
                  ? 'Ningún producto con margen menor a 15%.'
                  : 'Sin productos vendidos en el período.',
              style: const TextStyle(color: Colors.black54),
            ),
          )
        else
          for (final p in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        Text(
                          '${qty(p.quantity)} u. · vendido ${money(p.revenue)}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        money(p.profit),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${p.margin.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 12,
                          color: _marginColor(p.margin),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
      ],
    );
  }

  static const _days = ['Lun', 'Mar', 'Mié', 'Jue', 'Vie', 'Sáb', 'Dom'];

  static String _dayLabel(String iso) {
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${_days[d.weekday - 1]} ${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
  }
}

Color _marginColor(double m) => m < 0
    ? Colors.red.shade700
    : m < 15
    ? Colors.orange.shade800
    : Colors.green.shade700;

/// Fila de una venta / OT: código, fecha, cliente, vendido y ganancia.
class _TransactionRow extends StatelessWidget {
  final ProfitTransaction t;
  const _TransactionRow({required this.t});

  @override
  Widget build(BuildContext context) {
    final date = t.date.length >= 16
        ? '${t.date.substring(8, 10)}/${t.date.substring(5, 7)} ${t.date.substring(11, 16)}'
        : t.date;
    Widget badge(String text, Color color) => Container(
      margin: const EdgeInsets.only(left: 4),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 10,
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        t.code.isEmpty ? (t.isOt ? 'OT' : 'Venta') : t.code,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    if (t.isOt) badge('OT', Colors.orange.shade800),
                    if (t.credit) badge('Crédito', Colors.blue.shade700),
                    if (t.estimated) badge('estimada', Colors.blueGrey),
                  ],
                ),
                Text(
                  '$date · ${t.client ?? 'Sin cliente'}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                Text(
                  'Vendido ${money(t.revenue)} · costo ${money(t.cost)}'
                  '${t.interest > 0 ? ' (incl. ${money(t.interest)} interés)' : ''}'
                  '${t.quick > 0 ? ' · + ${money(t.quick)} rápida' : ''}',
                  maxLines: 2,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                if (t.balance > 0)
                  Text(
                    'Debe ${money(t.balance)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: Colors.red.shade700,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(t.profit),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: t.profit < 0
                      ? Colors.red.shade700
                      : Colors.green.shade700,
                ),
              ),
              if (t.revenue > 0)
                Text(
                  '${t.margin.toStringAsFixed(1)}%',
                  style: TextStyle(fontSize: 12, color: _marginColor(t.margin)),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tarjeta principal: ganancia grande + ingresos, costo y margen.
class _ProfitHero extends StatelessWidget {
  final ProfitReport r;
  const _ProfitHero({required this.r});

  @override
  Widget build(BuildContext context) {
    final positive = r.profit >= 0;
    final color = positive ? Colors.green.shade700 : Colors.red.shade700;
    final totalCost = r.cost + r.commission;
    return Card(
      color: color.withValues(alpha: .08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        positive ? 'Ganancia' : 'Pérdida',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Colors.black54,
                        ),
                      ),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          money(r.profit),
                          key: const Key('profit_total'),
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _marginColor(r.margin).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Margen ${r.margin.toStringAsFixed(1)}%',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: _marginColor(r.margin),
                    ),
                  ),
                ),
              ],
            ),
            const Divider(height: 20),
            Row(
              children: [
                Expanded(child: _Kpi('Ingresos', money(r.revenue))),
                const SizedBox(width: 12),
                Expanded(child: _Kpi('Costo', money(totalCost))),
              ],
            ),
            if (r.commission > 0)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  'Costo = productos ${money(r.cost)} + comisión ${money(r.commission)}',
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  final String label;
  final String value;
  const _Kpi(this.label, this.value);

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
      FittedBox(
        fit: BoxFit.scaleDown,
        alignment: Alignment.centerLeft,
        child: Text(
          value,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
      ),
    ],
  );
}

class _Notice extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String text;
  const _Notice({required this.color, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Container(
    margin: const EdgeInsets.only(bottom: 8),
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .10),
      borderRadius: BorderRadius.circular(10),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12))),
      ],
    ),
  );
}

class _Section extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? trailing;
  final List<Widget> children;
  const _Section({
    required this.icon,
    required this.color,
    required this.title,
    this.trailing,
    required this.children,
  });

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 10),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: color),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              // El texto de la derecha cede espacio (con …) si no cabe.
              Expanded(
                child: Text(
                  trailing ?? '',
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    ),
  );
}

class _Line extends StatelessWidget {
  final String label;
  final String value;
  final bool muted;
  const _Line(this.label, this.value, {this.muted = false});

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(color: muted ? Colors.black54 : null);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: style)),
          const SizedBox(width: 8),
          Text(value, style: style),
        ],
      ),
    );
  }
}

class _ProfitLine extends StatelessWidget {
  final double profit;
  final double margin;
  const _ProfitLine(this.profit, this.margin);

  @override
  Widget build(BuildContext context) => Column(
    children: [
      const Divider(),
      Row(
        children: [
          const Expanded(
            child: Text(
              'Ganancia',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            money(profit),
            style: TextStyle(
              fontWeight: FontWeight.w800,
              color: profit < 0 ? Colors.red.shade700 : Colors.green.shade700,
            ),
          ),
          const SizedBox(width: 6),
          Text(
            '(${margin.toStringAsFixed(1)}%)',
            style: TextStyle(fontSize: 12, color: _marginColor(margin)),
          ),
        ],
      ),
    ],
  );
}
