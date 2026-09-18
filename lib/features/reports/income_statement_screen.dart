import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import 'income_statement_repository.dart';

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Estado de resultados por movimientos (caja + tesorería).
class IncomeStatementScreen extends ConsumerStatefulWidget {
  const IncomeStatementScreen({super.key});

  @override
  ConsumerState<IncomeStatementScreen> createState() =>
      _IncomeStatementScreenState();
}

enum _Preset { thisWeek, lastWeek, thisMonth, lastMonth, all, custom }

/// "yyyy-mm-dd" → "dd/mm/yyyy".
String _dmy(String iso) {
  final p = iso.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
}

class _IncomeStatementScreenState extends ConsumerState<IncomeStatementScreen> {
  _Preset _preset = _Preset.thisMonth;
  late DateTime _from;
  late DateTime _to;

  @override
  void initState() {
    super.initState();
    _applyPreset(_Preset.thisMonth);
  }

  void _applyPreset(_Preset p) {
    final now = DateTime.now();
    setState(() {
      _preset = p;
      // Semana de lunes a domingo (la actual termina hoy).
      final today = DateTime(now.year, now.month, now.day);
      final monday = today.subtract(Duration(days: today.weekday - 1));
      switch (p) {
        case _Preset.thisWeek:
          _from = monday;
          _to = today;
          break;
        case _Preset.lastWeek:
          _from = monday.subtract(const Duration(days: 7));
          _to = monday.subtract(const Duration(days: 1));
          break;
        case _Preset.thisMonth:
          _from = DateTime(now.year, now.month, 1);
          _to = now;
          break;
        case _Preset.lastMonth:
          _from = DateTime(now.year, now.month - 1, 1);
          _to = DateTime(now.year, now.month, 0); // último día del mes anterior
          break;
        case _Preset.all:
          // El rango real lo decide el backend (primer movimiento → hoy).
          break;
        case _Preset.custom:
          break;
      }
    });
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime(DateTime.now().year + 1),
      initialDateRange: DateTimeRange(start: _from, end: _to),
    );
    if (picked != null) {
      setState(() {
        _preset = _Preset.custom;
        _from = picked.start;
        _to = picked.end;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final key = _preset == _Preset.all
        ? incomeStatementAllKey
        : '${_ymd(_from)}|${_ymd(_to)}';
    final async = ref.watch(incomeStatementProvider(key));

    // Cabecera de rango: en "Todo" se muestra la fecha real del primer
    // movimiento que devuelve el backend.
    final String rangeText;
    if (_preset == _Preset.all) {
      final from = async.valueOrNull?.from;
      rangeText = from == null || from.isEmpty
          ? 'Desde el inicio  —  hoy'
          : 'Desde ${_dmy(from)}  —  hoy';
    } else {
      rangeText = '${_ymd(_from)}  —  ${_ymd(_to)}';
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Estado de resultados')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            // Seis presets: fila desplazable de chips (no caben como segmentos).
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final e in const {
                    _Preset.thisWeek: 'Esta semana',
                    _Preset.lastWeek: 'Semana ant.',
                    _Preset.thisMonth: 'Este mes',
                    _Preset.lastMonth: 'Mes ant.',
                    _Preset.all: 'Todo',
                    _Preset.custom: 'Rango',
                  }.entries)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: _preset == e.key,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) {
                          if (e.key == _Preset.custom) {
                            _pickRange();
                          } else {
                            _applyPreset(e.key);
                          }
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                rangeText,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(incomeStatementProvider(key)),
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
                    _section('Ingresos', r.income, r.totalIncome, Colors.green),
                    const SizedBox(height: 12),
                    _section('Egresos', r.expense, r.totalExpense, Colors.red),
                    const SizedBox(height: 12),
                    _resultCard(r.net, _preset == _Preset.all),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
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
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
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
