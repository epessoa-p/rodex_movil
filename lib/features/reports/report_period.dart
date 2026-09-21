import 'package:flutter/material.dart';

/// Presets de período de los reportes (Finanzas: resultados, movimientos y
/// cierres). "Todo" deja el rango al backend (primer movimiento → hoy).
enum ReportPreset { thisWeek, lastWeek, thisMonth, lastMonth, all, custom }

const reportPresetLabels = {
  ReportPreset.thisWeek: 'Esta semana',
  ReportPreset.lastWeek: 'Semana ant.',
  ReportPreset.thisMonth: 'Este mes',
  ReportPreset.lastMonth: 'Mes ant.',
  ReportPreset.all: 'Todo',
  ReportPreset.custom: 'Rango',
};

/// Período elegido: preset + rango calculado (lunes–domingo para semanas).
class ReportPeriod {
  final ReportPreset preset;
  final DateTime from;
  final DateTime to;
  const ReportPeriod(this.preset, this.from, this.to);

  bool get isAll => preset == ReportPreset.all;

  /// Clave estable para providers (`from|to` o `all`).
  String get key => isAll ? 'all' : '${ymd(from)}|${ymd(to)}';

  /// Parámetros para la API: `preset=all` o `from/to`.
  Map<String, dynamic> get query =>
      isAll ? {'preset': 'all'} : {'from': ymd(from), 'to': ymd(to)};

  /// Texto de cabecera; en "Todo" se puede pasar la fecha real de inicio.
  String label({String? allFrom}) {
    if (isAll) {
      return allFrom == null || allFrom.isEmpty
          ? 'Desde el inicio  —  hoy'
          : 'Desde ${dmy(allFrom)}  —  hoy';
    }
    return '${ymd(from)}  —  ${ymd(to)}';
  }

  factory ReportPeriod.of(ReportPreset p, {DateTime? now}) {
    final n = now ?? DateTime.now();
    final today = DateTime(n.year, n.month, n.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return switch (p) {
      ReportPreset.thisWeek => ReportPeriod(p, monday, today),
      ReportPreset.lastWeek => ReportPeriod(
        p,
        monday.subtract(const Duration(days: 7)),
        monday.subtract(const Duration(days: 1)),
      ),
      ReportPreset.thisMonth => ReportPeriod(
        p,
        DateTime(n.year, n.month, 1),
        today,
      ),
      ReportPreset.lastMonth => ReportPeriod(
        p,
        DateTime(n.year, n.month - 1, 1),
        DateTime(n.year, n.month, 0), // último día del mes anterior
      ),
      // El rango real lo decide el backend; se deja el mes como referencia.
      ReportPreset.all => ReportPeriod(p, DateTime(n.year, n.month, 1), today),
      ReportPreset.custom => ReportPeriod(p, today, today),
    };
  }

  ReportPeriod custom(DateTime from, DateTime to) =>
      ReportPeriod(ReportPreset.custom, from, to);

  static String ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  /// "yyyy-mm-dd" → "dd/mm/yyyy".
  static String dmy(String iso) {
    final p = iso.split('-');
    return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
  }
}

/// Fila desplazable de chips de período + texto del rango. Con [allowAll]
/// en false no ofrece "Todo" (listados que no deben traer todo el historial).
class PeriodChips extends StatelessWidget {
  final ReportPeriod period;
  final ValueChanged<ReportPeriod> onChanged;
  final bool allowAll;
  final String? allFrom;
  const PeriodChips({
    super.key,
    required this.period,
    required this.onChanged,
    this.allowAll = true,
    this.allFrom,
  });

  Future<void> _pickRange(BuildContext context) async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime(DateTime.now().year + 1),
      initialDateRange: DateTimeRange(start: period.from, end: period.to),
    );
    if (picked != null) onChanged(period.custom(picked.start, picked.end));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final e in reportPresetLabels.entries)
                  if (allowAll || e.key != ReportPreset.all)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(e.value),
                        selected: period.preset == e.key,
                        visualDensity: VisualDensity.compact,
                        onSelected: (_) {
                          if (e.key == ReportPreset.custom) {
                            _pickRange(context);
                          } else {
                            onChanged(ReportPeriod.of(e.key));
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
          child: Text(
            period.label(allFrom: allFrom),
            style: const TextStyle(fontSize: 12, color: Colors.black54),
          ),
        ),
      ],
    );
  }
}
