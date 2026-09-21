import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/module_colors.dart';
import '../../core/providers.dart';
import 'finance_report_repository.dart';
import 'income_statement_screen.dart';
import 'report_period.dart';

/// Reporte de Finanzas: un solo período para tres tabs — Resultados (estado
/// de resultados), Movimientos (ingresos/egresos de caja) y Cierres de caja.
class FinanceReportScreen extends ConsumerStatefulWidget {
  /// Tab inicial: 0 resultados · 1 movimientos · 2 cierres.
  final int initialTab;
  const FinanceReportScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<FinanceReportScreen> createState() =>
      _FinanceReportScreenState();
}

class _Tab {
  final String label;
  final IconData icon;
  final Color color;
  final Widget body;
  const _Tab(this.label, this.icon, this.color, this.body);
}

class _FinanceReportScreenState extends ConsumerState<FinanceReportScreen>
    with SingleTickerProviderStateMixin {
  ReportPeriod _period = ReportPeriod.of(ReportPreset.thisMonth);
  int? _branchId;
  TabController? _tabs;

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).me;
    if (me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final canResults = me.can('income-statement.view');
    final canCash = me.planAllows('cash') && me.can('cash-registers.view');

    final tabs = <_Tab>[
      if (canResults)
        _Tab(
          'Resultados',
          Icons.assessment_outlined,
          ModuleColors.sales,
          IncomeStatementView(period: _period),
        ),
      if (canCash) ...[
        _Tab(
          'Movimientos',
          Icons.swap_vert,
          ModuleColors.treasury,
          _MovementsTab(
            period: _period,
            branchId: _branchId,
            onBranch: (b) => setState(() => _branchId = b),
          ),
        ),
        _Tab(
          'Cierres',
          Icons.lock_clock_outlined,
          ModuleColors.payments,
          _ClosuresTab(period: _period, branchId: _branchId),
        ),
      ],
    ];

    if (tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Finanzas')),
        body: const Center(child: Text('No tienes acceso a este reporte.')),
      );
    }
    if (_tabs == null || _tabs!.length != tabs.length) {
      _tabs?.dispose();
      _tabs = TabController(
        length: tabs.length,
        vsync: this,
        initialIndex: widget.initialTab.clamp(0, tabs.length - 1),
      );
      _tabs!.addListener(() {
        if (!_tabs!.indexIsChanging) setState(() {});
      });
    }
    final active = tabs[_tabs!.index].color;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Finanzas'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            for (final t in tabs)
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.icon, size: 16),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        t.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Franja del color del tab + selector de período compartido.
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 3,
            color: active,
          ),
          PeriodChips(
            period: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [for (final t in tabs) t.body],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Movimientos ───────────────────────────────────────────────────────

class _MovementsTab extends ConsumerStatefulWidget {
  final ReportPeriod period;
  final int? branchId;
  final ValueChanged<int?> onBranch;
  const _MovementsTab({
    required this.period,
    required this.branchId,
    required this.onBranch,
  });

  @override
  ConsumerState<_MovementsTab> createState() => _MovementsTabState();
}

class _MovementsTabState extends ConsumerState<_MovementsTab> {
  String _kind = 'all'; // all | income | expense

  @override
  Widget build(BuildContext context) {
    final key = cashReportKey(widget.period, widget.branchId);
    final async = ref.watch(cashReportProvider(key));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(cashReportProvider(key)),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: 80),
            Center(child: Text('$e', textAlign: TextAlign.center)),
          ],
        ),
        data: (r) {
          final rows = r.movements
              .where((m) => _kind == 'all' || m.type == _kind)
              .toList();
          final groups = _groupByDay(rows);
          final maxCat = r.byCategory.isEmpty
              ? 0.0
              : r.byCategory
                    .map((c) => c.amount)
                    .reduce((a, b) => a > b ? a : b);
          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            children: [
              _Kpis(income: r.income, expense: r.expense, balance: r.balance),
              const SizedBox(height: 10),
              _Filters(
                branches: r.branches,
                branchId: widget.branchId,
                onBranch: widget.onBranch,
                kind: _kind,
                onKind: (k) => setState(() => _kind = k),
              ),
              if (r.byCategory.isNotEmpty) ...[
                const SizedBox(height: 12),
                const _SectionTitle('Por categoría'),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                    child: Column(
                      children: [
                        for (final c in r.byCategory)
                          if (_kind == 'all' || c.type == _kind)
                            _CategoryBar(c: c, max: maxCat),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              _SectionTitle(
                'Movimientos (${rows.length}${r.truncated ? ' de ${r.totalCount}' : ''})',
              ),
              if (r.truncated)
                const Padding(
                  padding: EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Se muestran los 300 más recientes; acota el período para ver todos.',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
              if (rows.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'Sin movimientos en el período.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ),
              for (final g in groups) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 10, 4, 4),
                  child: Text(
                    g.$1,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.black54,
                      fontSize: 12,
                    ),
                  ),
                ),
                Card(
                  child: Column(
                    children: [
                      for (var i = 0; i < g.$2.length; i++) ...[
                        if (i > 0) const Divider(height: 1),
                        _MovementTile(m: g.$2[i]),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  List<(String, List<CashMovementRow>)> _groupByDay(
    List<CashMovementRow> rows,
  ) {
    // Sin datos de locale de intl: nombres en español a mano.
    const days = [
      'Lunes',
      'Martes',
      'Miércoles',
      'Jueves',
      'Viernes',
      'Sábado',
      'Domingo',
    ];
    const months = [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ];
    final out = <(String, List<CashMovementRow>)>[];
    for (final m in rows) {
      final d = m.date?.toLocal();
      final label = d == null
          ? 'Sin fecha'
          : '${days[d.weekday - 1]} ${d.day} de ${months[d.month - 1]}';
      if (out.isEmpty || out.last.$1 != label) {
        out.add((label, [m]));
      } else {
        out.last.$2.add(m);
      }
    }
    return out;
  }
}

class _Kpis extends StatelessWidget {
  final double income;
  final double expense;
  final double balance;
  const _Kpis({
    required this.income,
    required this.expense,
    required this.balance,
  });

  @override
  Widget build(BuildContext context) {
    Widget kpi(String label, double v, Color c) => Expanded(
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: const TextStyle(
                  fontSize: 10,
                  color: Colors.black54,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 2),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  money(v),
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    color: c,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return Row(
      children: [
        kpi('Ingresos', income, Colors.green.shade700),
        const SizedBox(width: 8),
        kpi('Egresos', expense, Colors.red.shade700),
        const SizedBox(width: 8),
        kpi('Balance', balance, balance >= 0 ? Colors.black87 : Colors.red),
      ],
    );
  }
}

class _Filters extends StatelessWidget {
  final List<dynamic> branches;
  final int? branchId;
  final ValueChanged<int?> onBranch;
  final String kind;
  final ValueChanged<String> onKind;
  const _Filters({
    required this.branches,
    required this.branchId,
    required this.onBranch,
    required this.kind,
    required this.onKind,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final e in const {
            'all': 'Todos',
            'income': 'Ingresos',
            'expense': 'Egresos',
          }.entries)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: Text(e.value),
                selected: kind == e.key,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onKind(e.key),
              ),
            ),
          if (branches.length > 1) ...[
            const SizedBox(width: 6),
            const Text('|', style: TextStyle(color: Colors.black26)),
            const SizedBox(width: 6),
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: FilterChip(
                label: const Text('Todas'),
                selected: branchId == null,
                visualDensity: VisualDensity.compact,
                onSelected: (_) => onBranch(null),
              ),
            ),
            for (final b in branches)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: FilterChip(
                  label: Text(b.name as String),
                  selected: branchId == b.id,
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => onBranch(b.id as int),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
    ),
  );
}

class _CategoryBar extends StatelessWidget {
  final CategoryTotal c;
  final double max;
  const _CategoryBar({required this.c, required this.max});

  @override
  Widget build(BuildContext context) {
    final color = c.type == 'income' ? Colors.green : Colors.red;
    final ratio = max <= 0 ? 0.0 : (c.amount / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Text(
                money(c.amount),
                style: TextStyle(fontWeight: FontWeight.w700, color: color),
              ),
            ],
          ),
          const SizedBox(height: 3),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: color.withValues(alpha: .10),
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final CashMovementRow m;
  const _MovementTile({required this.m});

  @override
  Widget build(BuildContext context) {
    final color = m.isIncome ? Colors.green.shade700 : Colors.red.shade700;
    final time = m.date == null
        ? ''
        : DateFormat('HH:mm').format(m.date!.toLocal());
    final meta = [
      if (time.isNotEmpty) time,
      if (m.register != null && m.register!.isNotEmpty) m.register!,
      if (m.branch != null && m.branch!.isNotEmpty) m.branch!,
      if (m.method != null && m.method!.isNotEmpty) m.method!,
    ].join(' · ');
    return ListTile(
      dense: true,
      leading: CircleAvatar(
        radius: 16,
        backgroundColor: color.withValues(alpha: .12),
        child: Icon(
          m.isIncome ? Icons.arrow_downward : Icons.arrow_upward,
          size: 16,
          color: color,
        ),
      ),
      title: Text(
        m.description?.isNotEmpty == true ? m.description! : m.category,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        [m.category, if (meta.isNotEmpty) meta].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${m.isIncome ? '+' : '−'}${money(m.amount)}',
        style: TextStyle(fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}

// ── Cierres ───────────────────────────────────────────────────────────

class _ClosuresTab extends ConsumerWidget {
  final ReportPeriod period;
  final int? branchId;
  const _ClosuresTab({required this.period, required this.branchId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = cashReportKey(period, branchId);
    final async = ref.watch(cashReportProvider(key));
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(cashReportProvider(key)),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: 80),
            Center(child: Text('$e', textAlign: TextAlign.center)),
          ],
        ),
        data: (r) => r.closures.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 80),
                  Center(
                    child: Text(
                      'Sin cierres de caja en el período.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  ),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
                children: [for (final c in r.closures) _ClosureCard(c: c)],
              ),
      ),
    );
  }
}

class _ClosureCard extends StatelessWidget {
  final CashClosure c;
  const _ClosureCard({required this.c});

  @override
  Widget build(BuildContext context) {
    final df = DateFormat('dd/MM HH:mm');
    final diff = c.difference;
    final (diffLabel, diffColor) = diff == null
        ? ('—', Colors.black45)
        : diff.abs() < 0.005
        ? ('Exacto', Colors.green.shade700)
        : diff < 0
        ? ('Faltante ${money(diff.abs())}', Colors.red.shade700)
        : ('Sobrante ${money(diff)}', Colors.blue.shade700);
    Widget row(String k, String v, {Color? color, bool bold = false}) =>
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  k,
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),
              Text(
                v,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        );
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    [
                      c.register ?? 'Caja',
                      if (c.branch != null && c.branch!.isNotEmpty) c.branch!,
                    ].join(' · '),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: (c.isOpen ? Colors.orange : Colors.green).withValues(
                      alpha: .14,
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    c.isOpen ? 'Abierta' : 'Cerrada',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: c.isOpen
                          ? Colors.orange.shade900
                          : Colors.green.shade800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Abrió ${c.openedBy ?? '—'}${c.openedAt != null ? ' · ${df.format(c.openedAt!.toLocal())}' : ''}'
              '${c.isOpen ? '' : '\nCerró ${c.closedBy ?? '—'}${c.closedAt != null ? ' · ${df.format(c.closedAt!.toLocal())}' : ''}'}',
              style: const TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const Divider(height: 16),
            row('Apertura', money(c.openingAmount)),
            row(
              'Ingresos',
              '+${money(c.income)}',
              color: Colors.green.shade700,
            ),
            row('Egresos', '−${money(c.expense)}', color: Colors.red.shade700),
            row('Esperado', money(c.expectedAmount), bold: true),
            if (!c.isOpen) ...[
              row('Contado', money(c.closingAmount ?? 0), bold: true),
              row('Diferencia', diffLabel, color: diffColor, bold: true),
            ],
            if (c.notes != null && c.notes!.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  c.notes!,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
