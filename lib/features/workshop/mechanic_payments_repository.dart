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

/// Un pago realizado (liquidó una o varias OTs).
class MechanicPaymentItem {
  final int id;
  final String? date;
  final double amount;
  final String? method;
  final String source; // cash | treasury
  final String? account;
  final String? notes;
  final List<MechanicOt> orders;

  MechanicPaymentItem({
    required this.id,
    this.date,
    required this.amount,
    this.method,
    required this.source,
    this.account,
    this.notes,
    required this.orders,
  });

  String get sourceLabel => source == 'treasury'
      ? 'Tesorería${account != null ? ' · $account' : ''}'
      : 'Caja';

  factory MechanicPaymentItem.fromJson(Map<String, dynamic> j) =>
      MechanicPaymentItem(
        id: j['id'] as int,
        date: j['date'] as String?,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        method: j['method'] as String?,
        source: (j['source'] ?? 'cash') as String,
        account: j['account'] as String?,
        notes: j['notes'] as String?,
        orders: ((j['orders'] as List?) ?? [])
            .map((e) => MechanicOt.fromJson(e as Map<String, dynamic>, paid: true))
            .toList(),
      );
}

/// Detalle de un mecánico: resumen + OTs pendientes y pagos realizados.
class MechanicDetail {
  final int id;
  final String name;
  final double commissionRate;
  final double pendingTotal;
  final double paidTotal;
  final List<MechanicOt> pending;
  final List<MechanicPaymentItem> payments;

  MechanicDetail({
    required this.id,
    required this.name,
    required this.commissionRate,
    required this.pendingTotal,
    required this.paidTotal,
    required this.pending,
    required this.payments,
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
      payments: ((j['payments'] as List?) ?? [])
          .map((e) => MechanicPaymentItem.fromJson(e as Map<String, dynamic>))
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

  /// Liquida las OTs seleccionadas pagando `amount` (editable). Las OTs quedan
  /// vinculadas al pago. Devuelve el detalle actualizado.
  Future<MechanicDetail> pay({
    required int mechanicId,
    required List<int> workOrderIds,
    required double amount,
    required String paymentSource, // 'cash' | 'treasury'
    int? treasuryAccountId,
    String? method,
    String? notes,
  }) async {
    final data = await _api.post('/mechanic-payments', body: {
      'mechanic_id': mechanicId,
      'work_order_ids': workOrderIds,
      'amount': amount,
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
