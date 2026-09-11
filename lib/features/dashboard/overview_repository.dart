import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

double _d(dynamic v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);
int _i(dynamic v) => v == null ? 0 : (v is num ? v.toInt() : int.tryParse('$v') ?? 0);

/// Ventas completadas de hoy.
class SalesToday {
  final int count;
  final double total;
  SalesToday({required this.count, required this.total});
  factory SalesToday.fromJson(Map<String, dynamic> j) =>
      SalesToday(count: _i(j['count']), total: _d(j['total']));
}

/// Próxima cita del día.
class NextAppointment {
  final int id;
  final String? time;
  final String? client;
  final String? title;
  NextAppointment({required this.id, this.time, this.client, this.title});
  factory NextAppointment.fromJson(Map<String, dynamic> j) => NextAppointment(
        id: _i(j['id']),
        time: j['time'] as String?,
        client: j['client'] as String?,
        title: j['title'] as String?,
      );
}

class AppointmentsToday {
  final int total;
  final int pending;
  final NextAppointment? next;
  AppointmentsToday({required this.total, required this.pending, this.next});
  factory AppointmentsToday.fromJson(Map<String, dynamic> j) => AppointmentsToday(
        total: _i(j['total']),
        pending: _i(j['pending']),
        next: j['next'] == null
            ? null
            : NextAppointment.fromJson(j['next'] as Map<String, dynamic>),
      );
}

/// Un servicio en el ranking de ingresos del mes.
class ServiceSale {
  final String label;
  final double amount;
  final int count;
  ServiceSale({required this.label, required this.amount, required this.count});
  factory ServiceSale.fromJson(Map<String, dynamic> j) => ServiceSale(
        label: (j['label'] ?? '') as String,
        amount: _d(j['amount']),
        count: _i(j['count']),
      );
}

class WorkshopOverview {
  final int receivedToday;
  final int active;
  final int vehiclesInShop;
  final Map<String, int> byStatus; // recibida, diagnosticada, en_proceso, terminada
  final AppointmentsToday appointments;
  final List<ServiceSale> topServices;
  final List<WorkOrder> recent;

  WorkshopOverview({
    required this.receivedToday,
    required this.active,
    required this.vehiclesInShop,
    required this.byStatus,
    required this.appointments,
    required this.topServices,
    required this.recent,
  });

  factory WorkshopOverview.fromJson(Map<String, dynamic> j) => WorkshopOverview(
        receivedToday: _i(j['received_today']),
        active: _i(j['active']),
        vehiclesInShop: _i(j['vehicles_in_shop']),
        byStatus: ((j['by_status'] as Map?) ?? {})
            .map((k, v) => MapEntry(k.toString(), _i(v))),
        appointments: AppointmentsToday.fromJson(
            (j['appointments'] as Map<String, dynamic>?) ?? const {}),
        topServices: ((j['top_services'] as List?) ?? [])
            .map((e) => ServiceSale.fromJson(e as Map<String, dynamic>))
            .toList(),
        recent: ((j['recent'] as List?) ?? [])
            .map((e) => WorkOrder.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class StockOverview {
  final int inStock;
  final int lowStock;
  StockOverview({required this.inStock, required this.lowStock});
  factory StockOverview.fromJson(Map<String, dynamic> j) =>
      StockOverview(inStock: _i(j['in_stock']), lowStock: _i(j['low_stock']));
}

/// Resumen operativo del día. Las secciones vienen en null cuando el plan no
/// tiene el módulo o el usuario no tiene el permiso de ese dashboard.
class DashboardOverview {
  final String date;
  final SalesToday? sales;
  final WorkshopOverview? workshop;
  final StockOverview? stock;

  DashboardOverview({required this.date, this.sales, this.workshop, this.stock});

  factory DashboardOverview.fromJson(Map<String, dynamic> j) => DashboardOverview(
        date: (j['date'] ?? '') as String,
        sales: j['sales'] == null
            ? null
            : SalesToday.fromJson(j['sales'] as Map<String, dynamic>),
        workshop: j['workshop'] == null
            ? null
            : WorkshopOverview.fromJson(j['workshop'] as Map<String, dynamic>),
        stock: j['stock'] == null
            ? null
            : StockOverview.fromJson(j['stock'] as Map<String, dynamic>),
      );
}

class OverviewRepository {
  final ApiClient _api;
  OverviewRepository(this._api);

  Future<DashboardOverview> overview() async {
    final data = await _api.get('/dashboard/overview');
    return DashboardOverview.fromJson((data as Map<String, dynamic>)['data']);
  }
}

final overviewRepositoryProvider = Provider<OverviewRepository>(
  (ref) => OverviewRepository(ref.read(apiClientProvider)),
);

final dashboardOverviewProvider = FutureProvider.autoDispose<DashboardOverview>(
  (ref) => ref.read(overviewRepositoryProvider).overview(),
);
