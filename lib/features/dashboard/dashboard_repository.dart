import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';

/// Un punto de la serie (una semana o un mes).
class SeriesPoint {
  final String label;
  final double amount;
  final int count;
  SeriesPoint({required this.label, required this.amount, required this.count});

  factory SeriesPoint.fromJson(Map<String, dynamic> j) => SeriesPoint(
        label: (j['label'] ?? '') as String,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

/// Un día en la comparativa semana anterior vs. actual.
class WeekComparePoint {
  final String label;
  final double currentAmount;
  final int currentCount;
  final double prevAmount;
  final int prevCount;
  WeekComparePoint({
    required this.label,
    required this.currentAmount,
    required this.currentCount,
    required this.prevAmount,
    required this.prevCount,
  });

  factory WeekComparePoint.fromJson(Map<String, dynamic> j) => WeekComparePoint(
        label: (j['label'] ?? '') as String,
        currentAmount: (j['current_amount'] as num?)?.toDouble() ?? 0,
        currentCount: (j['current_count'] as num?)?.toInt() ?? 0,
        prevAmount: (j['prev_amount'] as num?)?.toDouble() ?? 0,
        prevCount: (j['prev_count'] as num?)?.toInt() ?? 0,
      );
}

/// Serie comparativa: semanal + mensual + comparación día por día de la semana.
class DashboardSeries {
  final List<SeriesPoint> weekly;
  final List<SeriesPoint> monthly;
  final List<WeekComparePoint> weekCompare;
  DashboardSeries(
      {required this.weekly,
      required this.monthly,
      required this.weekCompare});

  factory DashboardSeries.fromJson(Map<String, dynamic> j) => DashboardSeries(
        weekly: ((j['weekly'] as List?) ?? [])
            .map((e) => SeriesPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        monthly: ((j['monthly'] as List?) ?? [])
            .map((e) => SeriesPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        weekCompare: ((j['week_compare'] as List?) ?? [])
            .map((e) => WeekComparePoint.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

// ── Análisis → Top ─────────────────────────────────────────────────

/// Ingresos de un origen (Ventas / Taller / Alquileres) en el período.
class RevenueSlice {
  final String key;
  final String label;
  final double amount;
  final int count;
  RevenueSlice(
      {required this.key,
      required this.label,
      required this.amount,
      required this.count});

  factory RevenueSlice.fromJson(Map<String, dynamic> j) => RevenueSlice(
        key: (j['key'] ?? '') as String,
        label: (j['label'] ?? '') as String,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        count: (j['count'] as num?)?.toInt() ?? 0,
      );
}

/// Fila de un ranking: siempre trae monto y cantidad.
class RankRow {
  final String label;
  final double amount;
  final double qty;
  RankRow({required this.label, required this.amount, required this.qty});

  factory RankRow.fromJson(Map<String, dynamic> j) => RankRow(
        label: (j['label'] ?? '') as String,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        qty: (j['qty'] as num?)?.toDouble() ?? 0,
      );

  static List<RankRow>? listOrNull(dynamic v) => v == null
      ? null
      : (v as List)
          .map((e) => RankRow.fromJson(e as Map<String, dynamic>))
          .toList();
}

class DashboardTop {
  final String periodKey;
  final String periodLabel;
  final String from;
  final String to;
  final String by;
  final List<RevenueSlice> revenue;
  /// `null` = sección no habilitada (plan/permiso); `[]` = sin datos.
  final List<RankRow>? topProducts;
  final List<RankRow>? topServices;
  final List<RankRow>? topPurchases;
  final List<RankRow>? topClients;

  DashboardTop({
    required this.periodKey,
    required this.periodLabel,
    required this.from,
    required this.to,
    required this.by,
    required this.revenue,
    required this.topProducts,
    required this.topServices,
    required this.topPurchases,
    required this.topClients,
  });

  factory DashboardTop.fromJson(Map<String, dynamic> j) {
    final p = (j['period'] as Map<String, dynamic>?) ?? const {};
    return DashboardTop(
      periodKey: (p['key'] ?? 'month') as String,
      periodLabel: (p['label'] ?? '') as String,
      from: (p['from'] ?? '') as String,
      to: (p['to'] ?? '') as String,
      by: (j['by'] ?? 'amount') as String,
      revenue: ((j['revenue'] as List?) ?? [])
          .map((e) => RevenueSlice.fromJson(e as Map<String, dynamic>))
          .toList(),
      topProducts: RankRow.listOrNull(j['top_products']),
      topServices: RankRow.listOrNull(j['top_services']),
      topPurchases: RankRow.listOrNull(j['top_purchases']),
      topClients: RankRow.listOrNull(j['top_clients']),
    );
  }
}

class DashboardRepository {
  final ApiClient _api;
  DashboardRepository(this._api);

  Future<DashboardSeries> _get(String module) async {
    final data = await _api.get('/dashboard/$module');
    return DashboardSeries.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<DashboardSeries> sales() => _get('sales');
  Future<DashboardSeries> workshop() => _get('workshop');
  Future<DashboardSeries> purchases() => _get('purchases');

  /// `period`: month | last_month | quarter | year · `by`: amount | qty.
  Future<DashboardTop> top(String period, String by) async {
    final data = await _api
        .get('/dashboard/top', query: {'period': period, 'by': by});
    return DashboardTop.fromJson((data as Map<String, dynamic>)['data']);
  }
}

final dashboardRepositoryProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.read(apiClientProvider)),
);

/// Serie por módulo ('sales' | 'workshop' | 'purchases').
final dashboardSeriesProvider =
    FutureProvider.family<DashboardSeries, String>((ref, module) {
  final repo = ref.read(dashboardRepositoryProvider);
  return switch (module) {
    'workshop' => repo.workshop(),
    'purchases' => repo.purchases(),
    _ => repo.sales(),
  };
});

/// Top del período. Clave "period|by" (p. ej. "month|amount").
final dashboardTopProvider =
    FutureProvider.family<DashboardTop, String>((ref, key) {
  final parts = key.split('|');
  return ref
      .read(dashboardRepositoryProvider)
      .top(parts.first, parts.length > 1 ? parts[1] : 'amount');
});
