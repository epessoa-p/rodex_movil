import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import 'income_statement_repository.dart';
import 'report_period.dart';

/// Estado de resultados por movimientos (caja + tesorería), pantalla suelta.
/// La vista en sí ([IncomeStatementView]) también es el tab "Resultados"
/// del reporte de Finanzas.
class IncomeStatementScreen extends StatefulWidget {
  const IncomeStatementScreen({super.key});

  @override
  State<IncomeStatementScreen> createState() => _IncomeStatementScreenState();
}

class _IncomeStatementScreenState extends State<IncomeStatementScreen> {
  ReportPeriod _period = ReportPeriod.of(ReportPreset.thisMonth);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Estado de resultados')),
      body: IncomeStatementView(
        period: _period,
        onPeriodChanged: (p) => setState(() => _period = p),
      ),
    );
  }
}

/// Contenido del estado de resultados para un [period]. Si se pasa
/// [onPeriodChanged] muestra su propio selector de período arriba; si no,
/// el período lo controla el padre (tab de Finanzas).
class IncomeStatementView extends ConsumerWidget {
  final ReportPeriod period;
  final ValueChanged<ReportPeriod>? onPeriodChanged;
  const IncomeStatementView({
    super.key,
    required this.period,
    this.onPeriodChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = period.isAll ? incomeStatementAllKey : period.key;
    final async = ref.watch(incomeStatementProvider(key));

    return Column(
      children: [
        if (onPeriodChanged != null)
          PeriodChips(
            period: period,
            onChanged: onPeriodChanged!,
            allFrom: async.valueOrNull?.from,
          ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: () async => ref.invalidate(incomeStatementProvider(key)),
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => ListView(
                children: [
                  const SizedBox(height: 80),
                  Center(child: Text('$e', textAlign: TextAlign.center)),
                ],
              ),
              data: (r) => ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (onPeriodChanged == null && period.isAll)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        period.label(allFrom: r.from),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ),
                  _section('Ingresos', r.income, r.totalIncome, Colors.green),
                  const SizedBox(height: 12),
                  _section('Egresos', r.expense, r.totalExpense, Colors.red),
                  const SizedBox(height: 12),
                  _resultCard(r.net, period.isAll),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _section(
    String title,
    List<StatementLine> lines,
    double total,
    Color color,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(fontWeight: FontWeight.w700, color: color),
            ),
            const SizedBox(height: 4),
            if (lines.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Sin movimientos.',
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              for (final l in lines)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(child: Text(l.label)),
                      Text(money(l.amount)),
                    ],
                  ),
                ),
            const Divider(),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Total ${title.toLowerCase()}'),
                Text(
                  money(total),
                  style: TextStyle(fontWeight: FontWeight.w800, color: color),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _resultCard(double net, bool all) {
    final positive = net >= 0;
    final color = positive ? Colors.green : Colors.red;
    return Card(
      color: color.withValues(alpha: .10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    all ? 'Resultado acumulado' : 'Resultado del período',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  Text(
                    positive ? 'Utilidad' : 'Pérdida',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            Text(
              money(net),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
