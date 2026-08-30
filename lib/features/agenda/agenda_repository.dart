import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

/// Estados de una cita (coinciden con el backend).
const kAppointmentStatuses = <String, String>{
  'programada': 'Programada',
  'confirmada': 'Confirmada',
  'completada': 'Completada',
  'cancelada': 'Cancelada',
  'no_asistio': 'No asistió',
};

/// Cita de la agenda.
class Appointment {
  final int id;
  final String date; // YYYY-MM-DD
  final String time; // HH:mm
  final String? endTime;
  final int durationMinutes;
  final String status;
  final String statusLabel;
  final String? title;
  final String? notes;
  final String displayName;
  final String? displayPhone;
  final int? clientId;
  final String? customerName;
  final String? customerPhone;
  final int? vehicleId;
  final String? vehicleLabel;
  final int? serviceId;
  final String? serviceName;
  final int? mechanicId;
  final String? mechanicName;
  final int? workOrderId;

  Appointment({
    required this.id,
    required this.date,
    required this.time,
    this.endTime,
    required this.durationMinutes,
    required this.status,
    required this.statusLabel,
    this.title,
    this.notes,
    required this.displayName,
    this.displayPhone,
    this.clientId,
    this.customerName,
    this.customerPhone,
    this.vehicleId,
    this.vehicleLabel,
    this.serviceId,
    this.serviceName,
    this.mechanicId,
    this.mechanicName,
    this.workOrderId,
  });

  factory Appointment.fromJson(Map<String, dynamic> j) => Appointment(
        id: j['id'] as int,
        date: (j['date'] ?? '') as String,
        time: (j['time'] ?? '') as String,
        endTime: j['end_time'] as String?,
        durationMinutes: (j['duration_minutes'] as num?)?.toInt() ?? 60,
        status: (j['status'] ?? 'programada') as String,
        statusLabel: (j['status_label'] ?? '') as String,
        title: j['title'] as String?,
        notes: j['notes'] as String?,
        displayName: (j['display_name'] ?? 'Sin nombre') as String,
        displayPhone: j['display_phone'] as String?,
        clientId: j['client_id'] as int?,
        customerName: j['customer_name'] as String?,
        customerPhone: j['customer_phone'] as String?,
        vehicleId: j['vehicle_id'] as int?,
        vehicleLabel: j['vehicle_label'] as String?,
        serviceId: j['service_id'] as int?,
        serviceName: j['service_name'] as String?,
        mechanicId: j['mechanic_id'] as int?,
        mechanicName: j['mechanic_name'] as String?,
        workOrderId: j['work_order_id'] as int?,
      );
}

/// Citas de un día + resumen.
class AgendaDay {
  final String date;
  final int total;
  final int programada;
  final int confirmada;
  final int completada;
  final List<Appointment> appointments;

  AgendaDay({
    required this.date,
    required this.total,
    required this.programada,
    required this.confirmada,
    required this.completada,
    required this.appointments,
  });

  factory AgendaDay.fromJson(Map<String, dynamic> j) {
    final stats = (j['stats'] as Map<String, dynamic>?) ?? {};
    return AgendaDay(
      date: (j['date'] ?? '') as String,
      total: (stats['total'] as num?)?.toInt() ?? 0,
      programada: (stats['programada'] as num?)?.toInt() ?? 0,
      confirmada: (stats['confirmada'] as num?)?.toInt() ?? 0,
      completada: (stats['completada'] as num?)?.toInt() ?? 0,
      appointments: ((j['appointments'] as List?) ?? [])
          .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Catálogos para el formulario (servicios + mecánicos).
class AppointmentMeta {
  final List<IdName> services;
  final List<IdName> mechanics;
  AppointmentMeta({required this.services, required this.mechanics});

  factory AppointmentMeta.fromJson(Map<String, dynamic> j) => AppointmentMeta(
        services: ((j['services'] as List?) ?? [])
            .map((e) => IdName.fromJson(e as Map<String, dynamic>))
            .toList(),
        mechanics: ((j['mechanics'] as List?) ?? [])
            .map((e) => IdName.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class AgendaRepository {
  final ApiClient _api;
  AgendaRepository(this._api);

  Future<AgendaDay> day(String date) async {
    final data = await _api.get('/appointments', query: {'date': date});
    return AgendaDay.fromJson((data as Map<String, dynamic>)['data']);
  }

  /// Citas entre dos fechas (YYYY-MM-DD), para las vistas de semana/mes.
  Future<List<Appointment>> range(String from, String to) async {
    final data =
        await _api.get('/appointments/range', query: {'from': from, 'to': to});
    final d = (data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return ((d['appointments'] as List?) ?? [])
        .map((e) => Appointment.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<AppointmentMeta> meta() async {
    final data = await _api.get('/appointments/meta');
    return AppointmentMeta.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<Appointment> create(Map<String, dynamic> body) async {
    final data = await _api.post('/appointments', body: body);
    return Appointment.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<Appointment> update(int id, Map<String, dynamic> body) async {
    final data = await _api.put('/appointments/$id', body: body);
    return Appointment.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<Appointment> changeStatus(int id, String status) async {
    final data =
        await _api.post('/appointments/$id/status', body: {'status': status});
    return Appointment.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<void> delete(int id) async {
    await _api.delete('/appointments/$id');
  }

  /// Convierte la cita en OT. Devuelve {work_order_id, code}.
  Future<Map<String, dynamic>> convert(int id) async {
    final data = await _api.post('/appointments/$id/convert');
    return (data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }
}

final agendaRepositoryProvider = Provider<AgendaRepository>(
  (ref) => AgendaRepository(ref.read(apiClientProvider)),
);

/// Citas de un día (family por fecha YYYY-MM-DD).
final agendaDayProvider = FutureProvider.family<AgendaDay, String>(
  (ref, date) => ref.read(agendaRepositoryProvider).day(date),
);

/// Catálogos del formulario de cita.
final appointmentMetaProvider = FutureProvider<AppointmentMeta>(
  (ref) => ref.read(agendaRepositoryProvider).meta(),
);

/// Citas de un rango "from|to" (YYYY-MM-DD|YYYY-MM-DD) para semana/mes.
final agendaRangeProvider =
    FutureProvider.family<List<Appointment>, String>((ref, key) {
  final parts = key.split('|');
  return ref.read(agendaRepositoryProvider).range(parts[0], parts[1]);
});
