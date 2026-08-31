import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';

/// Fila de resumen por mecánico.
class MechanicPayEntry {
  final int id;
  final String name;
  final bool active;
  final double commissionRate;
  final double pending;
  final int pendingCount;
  final double paid;

  MechanicPayEntry({
    required this.id,
    required this.name,
    required this.active,
    required this.commissionRate,
    required this.pending,
    required this.pendingCount,
    required this.paid,
  });

  factory MechanicPayEntry.fromJson(Map<String, dynamic> j) => MechanicPayEntry(
        id: j['id'] as int,
        name: (j['name'] ?? '') as String,
        active: (j['active'] as bool?) ?? true,
        commissionRate: (j['commission_rate'] as num?)?.toDouble() ?? 0,
        pending: (j['pending'] as num?)?.toDouble() ?? 0,
        pendingCount: (j['pending_count'] as num?)?.toInt() ?? 0,
        paid: (j['paid'] as num?)?.toDouble() ?? 0,
      );
}

/// OT vinculada al mecánico (pendiente o pagada).
class MechanicOt {
  final int orderId;
  final String code;
  final String? date;
  final double commission;
  final bool paid;
  final String? paymentDate;

  MechanicOt({
    required this.orderId,
    required this.code,
    this.date,
    required this.commission,
    required this.paid,
    this.paymentDate,
  });

  factory MechanicOt.fromJson(Map<String, dynamic> j, {required bool paid}) =>
      MechanicOt(
        orderId: j['order_id'] as int,
        code: (j['code'] ?? '') as String,
        date: j['date'] as String?,
        commission: (j['commission'] as num?)?.toDouble() ?? 0,
        paid: paid,
        paymentDate: j['payment_date'] as String?,
      );
}

/// Detalle de un mecánico: resumen + OTs pendientes y pagadas.
class MechanicDetail {
  final int id;
  final String name;
  final double commissionRate;
  final double pendingTotal;
  final double paidTotal;
  final List<MechanicOt> pending;
  final List<MechanicOt> paid;

  MechanicDetail({
    required this.id,
    required this.name,
    required this.commissionRate,
    required this.pendingTotal,
    required this.paidTotal,
    required this.pending,
    required this.paid,
  });

  factory MechanicDetail.fromJson(Map<String, dynamic> j) {
    final m = (j['mechanic'] as Map<String, dynamic>?) ?? {};
    return MechanicDetail(
      id: (m['id'] as num?)?.toInt() ?? 0,
      name: (m['name'] ?? '') as String,
      commissionRate: (m['commission_rate'] as num?)?.toDouble() ?? 0,
      pendingTotal: (m['pending_total'] as num?)?.toDouble() ?? 0,
      paidTotal: (m['paid_total'] as num?)?.toDouble() ?? 0,
      pending: ((j['pending'] as List?) ?? [])
          .map((e) => MechanicOt.fromJson(e as Map<String, dynamic>, paid: false))
          .toList(),
      paid: ((j['paid'] as List?) ?? [])
          .map((e) => MechanicOt.fromJson(e as Map<String, dynamic>, paid: true))
          .toList(),
    );
  }
}

class MechanicPaymentsRepository {
  final ApiClient _api;
  MechanicPaymentsRepository(this._api);

  Future<List<MechanicPayEntry>> summary() async {
    final data = await _api.get('/mechanic-payments');
    final d = (data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return ((d['mechanics'] as List?) ?? [])
        .map((e) => MechanicPayEntry.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<MechanicDetail> detail(int mechanicId) async {
    final data = await _api.get('/mechanic-payments/$mechanicId');
    return MechanicDetail.fromJson((data as Map<String, dynamic>)['data']);
  }

  /// Liquida las OTs seleccionadas (+ bono). Devuelve el detalle actualizado.
  Future<MechanicDetail> pay({
    required int mechanicId,
    required List<int> workOrderIds,
    double bonus = 0,
    required String paymentSource, // 'cash' | 'treasury'
    int? treasuryAccountId,
    String? method,
    String? notes,
  }) async {
    final data = await _api.post('/mechanic-payments', body: {
      'mechanic_id': mechanicId,
      'work_order_ids': workOrderIds,
      'bonus': bonus,
      'payment_source': paymentSource,
      'treasury_account_id': ?treasuryAccountId,
      'method': ?method,
      'notes': ?notes,
    });
    return MechanicDetail.fromJson((data as Map<String, dynamic>)['data']);
  }
}

final mechanicPaymentsRepositoryProvider = Provider<MechanicPaymentsRepository>(
  (ref) => MechanicPaymentsRepository(ref.read(apiClientProvider)),
);

/// Liquidación de mecánicos (resumen).
final mechanicPaymentsProvider = FutureProvider<List<MechanicPayEntry>>(
  (ref) => ref.read(mechanicPaymentsRepositoryProvider).summary(),
);

/// Detalle de un mecánico (OTs pendientes/pagadas).
final mechanicDetailProvider =
    FutureProvider.family<MechanicDetail, int>(
  (ref, id) => ref.read(mechanicPaymentsRepositoryProvider).detail(id),
);
