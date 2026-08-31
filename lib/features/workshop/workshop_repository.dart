import 'package:dio/dio.dart';
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

  /// Listado completo de mecánicos (incluye inactivos) para administrar.
  Future<List<MechanicFull>> mechanicsFull() async {
    final data = await _api.get('/mechanics/all');
    return _list(data).map((e) => MechanicFull.fromJson(e)).toList();
  }

  Future<MechanicFull> createMechanic({
    required String name,
    String? specialty,
    String? phone,
    double? commissionRate,
    bool active = true,
  }) async {
    final data = await _api.post('/mechanics', body: {
      'name': name,
      'specialty': ?specialty,
      'phone': ?phone,
      'commission_rate': ?commissionRate,
      'active': active,
    });
    return MechanicFull.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<MechanicFull> updateMechanic(
    int id, {
    required String name,
    String? specialty,
    String? phone,
    double? commissionRate,
    bool active = true,
  }) async {
    final data = await _api.put('/mechanics/$id', body: {
      'name': name,
      'specialty': ?specialty,
      'phone': ?phone,
      'commission_rate': ?commissionRate,
      'active': active,
    });
    return MechanicFull.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<List<VehicleOption>> vehicles(int clientId) async {
    final data = await _api.get('/vehicles', query: {'client_id': clientId});
    return _list(data).map((e) => VehicleOption.fromJson(e)).toList();
  }

  Future<WorkOrder> createReception({
    required int clientId,
    int? vehicleId,
    Map<String, dynamic>? newVehicle,
    int? mechanicId,
    String? receptionDate,
    String? reportedIssue,
    int? mileage,
    String? fuelLevel,
    String? receivedItems,
    String? notes,
    int? appointmentId,
  }) async {
    final body = <String, dynamic>{
      'client_id': clientId,
      'vehicle_mode': newVehicle != null ? 'new' : 'existing',
      'vehicle_id': ?vehicleId,
      'vehicle': ?newVehicle,
      'mechanic_id': ?mechanicId,
      'reception_date': ?receptionDate,
      'reported_issue': ?reportedIssue,
      'mileage': ?mileage,
      'fuel_level': ?fuelLevel,
      'received_items': ?receivedItems,
      'notes': ?notes,
      'appointment_id': ?appointmentId,
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

  /// Asigna (o quita, con null) el mecánico de una OT.
  Future<WorkOrder> assignMechanic(int orderId, int? mechanicId) async {
    final data = await _api.post('/work-orders/$orderId/mechanic',
        body: {'mechanic_id': mechanicId});
    return WorkOrder.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<WorkOrder> saveDiagnosis(int orderId, String diagnosis) async {
    final data = await _api
        .post('/work-orders/$orderId/diagnosis', body: {'diagnosis': diagnosis});
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

  /// Enlace público de seguimiento de la OT (para compartir al cliente).
  Future<String> shareLink(int orderId) async {
    final data = await _api.get('/work-orders/$orderId/share');
    final d = (data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return (d['url'] ?? '') as String;
  }

  /// Fotos de una OT.
  Future<List<WoPhoto>> photos(int orderId) async {
    final data = await _api.get('/work-orders/$orderId/photos');
    return _list(data).map((e) => WoPhoto.fromJson(e)).toList();
  }

  /// Sube una o varias fotos (rutas de archivos locales) a la OT.
  Future<List<WoPhoto>> uploadPhotos(int orderId, List<String> paths) async {
    final form = FormData();
    for (final p in paths) {
      form.files.add(MapEntry(
        'photos[]',
        await MultipartFile.fromFile(p, filename: p.split(RegExp(r'[\\/]')).last),
      ));
    }
    final data = await _api.post('/work-orders/$orderId/photos', body: form);
    return _list(data).map((e) => WoPhoto.fromJson(e)).toList();
  }

  /// Elimina una foto de la OT.
  Future<void> deletePhoto(int orderId, int photoId) async {
    await _api.delete('/work-orders/$orderId/photos/$photoId');
  }

  /// Resumen de OTs del día (para el inicio): recibidas hoy y activas.
  Future<WorkOrdersSummary> todaySummary() async {
    final data = await _api.get('/work-orders/summary');
    return WorkOrdersSummary.fromJson((data as Map<String, dynamic>)['data']);
  }

  List<Map<String, dynamic>> _list(dynamic data) =>
      (((data as Map<String, dynamic>)['data'] as List?) ?? [])
          .cast<Map<String, dynamic>>();
}

/// Mecánico con todos sus campos (para la administración).
class MechanicFull {
  final int id;
  final String name;
  final String? specialty;
  final String? phone;
  final double commissionRate;
  final bool active;

  MechanicFull({
    required this.id,
    required this.name,
    this.specialty,
    this.phone,
    required this.commissionRate,
    required this.active,
  });

  factory MechanicFull.fromJson(Map<String, dynamic> j) => MechanicFull(
        id: j['id'] as int,
        name: (j['name'] ?? '') as String,
        specialty: j['specialty'] as String?,
        phone: j['phone'] as String?,
        commissionRate: (j['commission_rate'] as num?)?.toDouble() ?? 0,
        active: (j['active'] as bool?) ?? true,
      );
}

final workshopRepositoryProvider = Provider<WorkshopRepository>(
  (ref) => WorkshopRepository(ref.read(apiClientProvider)),
);

/// Listado completo de mecánicos (administración).
final mechanicsFullProvider = FutureProvider<List<MechanicFull>>(
  (ref) => ref.read(workshopRepositoryProvider).mechanicsFull(),
);

/// Órdenes activas (para la lista del taller).
final workOrdersProvider = FutureProvider<List<WorkOrder>>(
  (ref) => ref.read(workshopRepositoryProvider).orders(),
);

/// Resumen de OTs del día (para la pantalla de inicio).
final workOrdersSummaryProvider = FutureProvider<WorkOrdersSummary>(
  (ref) => ref.read(workshopRepositoryProvider).todaySummary(),
);
