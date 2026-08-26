import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

/// Acceso a los endpoints del módulo Taller.
class WorkshopRepository {
  final ApiClient _api;
  WorkshopRepository(this._api);

  Future<List<WorkOrder>> orders({String? status}) async {
    final data = await _api.get('/work-orders', query: {'status': ?status});
    return _list(data).map((e) => WorkOrder.fromJson(e)).toList();
  }

  Future<WorkOrder> order(int id) async {
    final data = await _api.get('/work-orders/$id');
    return WorkOrder.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<List<Mechanic>> mechanics() async {
    final data = await _api.get('/mechanics');
    return _list(data).map((e) => Mechanic.fromJson(e)).toList();
  }

  Future<List<VehicleOption>> vehicles(int clientId) async {
    final data = await _api.get('/vehicles', query: {'client_id': clientId});
    return _list(data).map((e) => VehicleOption.fromJson(e)).toList();
  }

  Future<WorkOrder> createReception({
    required int clientId,
    int? vehicleId,
    Map<String, dynamic>? newVehicle,
    String? reportedIssue,
    int? mileage,
  }) async {
    final body = <String, dynamic>{
      'client_id': clientId,
      'vehicle_mode': newVehicle != null ? 'new' : 'existing',
      'vehicle_id': ?vehicleId,
      'vehicle': ?newVehicle,
      'reported_issue': ?reportedIssue,
      'mileage': ?mileage,
    };
    final data = await _api.post('/work-orders', body: body);
    return WorkOrder.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<WorkOrder> addService(
    int orderId, {
    required String description,
    required double price,
    required int quantity,
    int? mechanicId,
  }) async {
    final data = await _api.post('/work-orders/$orderId/services', body: {
      'description': description,
      'price': price,
      'quantity': quantity,
      'mechanic_id': ?mechanicId,
    });
    return WorkOrder.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<WorkOrder> addPart(
    int orderId, {
    required int productId,
    required int quantity,
    required double unitPrice,
  }) async {
    final data = await _api.post('/work-orders/$orderId/parts', body: {
      'product_id': productId,
      'quantity': quantity,
      'unit_price': unitPrice,
    });
    return WorkOrder.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<WorkOrder> changeStatus(int orderId, String status) async {
    final data = await _api
        .post('/work-orders/$orderId/status', body: {'status': status});
    return WorkOrder.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<WorkOrder> deliver(int orderId, {String? deliveredTo}) async {
    final data = await _api.post('/work-orders/$orderId/deliver',
        body: {'delivered_to': ?deliveredTo});
    return WorkOrder.fromJson((data as Map<String, dynamic>)['data']);
  }

  List<Map<String, dynamic>> _list(dynamic data) =>
      (((data as Map<String, dynamic>)['data'] as List?) ?? [])
          .cast<Map<String, dynamic>>();
}

final workshopRepositoryProvider = Provider<WorkshopRepository>(
  (ref) => WorkshopRepository(ref.read(apiClientProvider)),
);

/// Órdenes activas (para la lista del taller).
final workOrdersProvider = FutureProvider<List<WorkOrder>>(
  (ref) => ref.read(workshopRepositoryProvider).orders(),
);
