import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

/// Fila de actividad del cliente (venta, OT, cita, alquiler): campos comunes
/// para pintar una lista uniforme por tab.
class ClientActivity {
  final int id;
  final String title; // código / fecha
  final String? subtitle; // vehículo, servicios, tipo…
  final String? date;
  final String? status; // clave (para color)
  final String? statusLabel;
  final double? amount;
  final String? extra; // estado de pago, OT generada…

  ClientActivity({
    required this.id,
    required this.title,
    this.subtitle,
    this.date,
    this.status,
    this.statusLabel,
    this.amount,
    this.extra,
  });
}

class ClientVehicle {
  final int id;
  final String label;
  final String? plate;
  final int? year;
  final String? color;
  ClientVehicle({
    required this.id,
    required this.label,
    this.plate,
    this.year,
    this.color,
  });

  factory ClientVehicle.fromJson(Map<String, dynamic> j) => ClientVehicle(
    id: j['id'] as int,
    label: (j['label'] ?? '') as String,
    plate: j['plate'] as String?,
    year: (j['year'] as num?)?.toInt(),
    color: j['color'] as String?,
  );
}

/// Ficha completa del cliente. Cada lista es `null` cuando el plan/permiso no
/// habilita ese tab.
class ClientDetail {
  final Client client;
  final String? notes;
  final bool active;
  final String? photoUrl;
  final String? createdAt;
  final List<ClientActivity>? sales;
  final List<ClientActivity>? workOrders;
  final List<ClientVehicle>? vehicles;
  final List<ClientActivity>? appointments;
  final List<ClientActivity>? rentals;

  ClientDetail({
    required this.client,
    this.notes,
    required this.active,
    this.photoUrl,
    this.createdAt,
    this.sales,
    this.workOrders,
    this.vehicles,
    this.appointments,
    this.rentals,
  });

  factory ClientDetail.fromJson(Map<String, dynamic> j) {
    List<ClientActivity>? rows(
      String key,
      ClientActivity Function(Map<String, dynamic>) map,
    ) => j[key] == null
        ? null
        : (j[key] as List).map((e) => map(e as Map<String, dynamic>)).toList();

    String? s(dynamic v) => v?.toString();
    double? d(dynamic v) => (v as num?)?.toDouble();

    return ClientDetail(
      client: Client.fromJson(j),
      notes: j['notes'] as String?,
      active: (j['active'] ?? true) as bool,
      photoUrl: j['photo_url'] as String?,
      createdAt: j['created_at'] as String?,
      sales: rows(
        'sales',
        (e) => ClientActivity(
          id: e['id'] as int,
          title: s(e['code']) ?? '',
          subtitle: s(e['type']),
          date: s(e['date']),
          amount: d(e['total']),
          extra: s(e['payment_status']),
        ),
      ),
      workOrders: rows(
        'work_orders',
        (e) => ClientActivity(
          id: e['id'] as int,
          title: s(e['code']) ?? '',
          subtitle: s(e['vehicle']),
          date: s(e['date']),
          status: s(e['status']),
          statusLabel: s(e['status_label']),
          amount: d(e['total']),
          extra: (d(e['balance']) ?? 0) > 0
              ? 'Saldo ${d(e['balance'])!.toStringAsFixed(2)}'
              : s(e['payment_status']),
        ),
      ),
      vehicles: j['vehicles'] == null
          ? null
          : (j['vehicles'] as List)
                .map((e) => ClientVehicle.fromJson(e as Map<String, dynamic>))
                .toList(),
      appointments: rows(
        'appointments',
        (e) => ClientActivity(
          id: e['id'] as int,
          title: '${s(e['date']) ?? ''} ${s(e['time']) ?? ''}'.trim(),
          subtitle: s(e['services']),
          date: s(e['date']),
          status: s(e['status']),
          statusLabel: s(e['status_label']),
          extra: e['work_order_code'] != null
              ? 'OT ${e['work_order_code']}'
              : null,
        ),
      ),
      rentals: rows(
        'rentals',
        (e) => ClientActivity(
          id: e['id'] as int,
          title: s(e['code']) ?? '',
          subtitle: s(e['moto']),
          date: s(e['date']),
          status: s(e['status']),
          statusLabel: s(e['status_label']),
          amount: d(e['total']),
          extra: s(e['payment_status']),
        ),
      ),
    );
  }
}

class ClientsRepository {
  final ApiClient _api;
  ClientsRepository(this._api);

  Future<ClientDetail> detail(int id) async {
    final data = await _api.get('/clients/$id');
    return ClientDetail.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<Client> update(
    int id, {
    required String fullName,
    required String phone,
    String? idNumber,
    String? email,
    String? address,
    String? notes,
    bool active = true,
  }) async {
    final data = await _api.put(
      '/clients/$id',
      body: {
        'full_name': fullName,
        'phone': phone,
        'id_number': idNumber,
        'email': email,
        'address': address,
        'notes': notes,
        'active': active,
      },
    );
    return Client.fromJson((data as Map<String, dynamic>)['data']);
  }
}

final clientsRepositoryProvider = Provider<ClientsRepository>(
  (ref) => ClientsRepository(ref.read(apiClientProvider)),
);

/// Ficha del cliente (family por id).
final clientDetailProvider = FutureProvider.autoDispose
    .family<ClientDetail, int>(
      (ref, id) => ref.read(clientsRepositoryProvider).detail(id),
    );
