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

/// Serie comparativa: semanal + mensual.
class DashboardSeries {
  final List<SeriesPoint> weekly;
  final List<SeriesPoint> monthly;
  DashboardSeries({required this.weekly, required this.monthly});

  factory DashboardSeries.fromJson(Map<String, dynamic> j) => DashboardSeries(
        weekly: ((j['weekly'] as List?) ?? [])
            .map((e) => SeriesPoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        monthly: ((j['monthly'] as List?) ?? [])
            .map((e) => SeriesPoint.fromJson(e as Map<String, dynamic>))
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
