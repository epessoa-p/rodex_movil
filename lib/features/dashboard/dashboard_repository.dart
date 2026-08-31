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
