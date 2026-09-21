import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import 'report_period.dart';

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

/// Documento con saldo: venta a crédito, OT entregada o compra a proveedor.
class AccountRow {
  final int id;
  final String type; // sale | work_order | purchase
  final String code;
  final String name; // cliente o proveedor
  final String? phone;
  final String? date;
  final String? dueDate;
  final double total;
  final double paid;
  final double balance;
  final int days;
  final bool overdue;

  AccountRow({
    required this.id,
    required this.type,
    required this.code,
    required this.name,
    this.phone,
    this.date,
    this.dueDate,
    required this.total,
    required this.paid,
    required this.balance,
    required this.days,
    required this.overdue,
  });

  factory AccountRow.fromJson(Map<String, dynamic> j) => AccountRow(
    id: j['id'] as int,
    type: (j['type'] ?? '') as String,
    code: (j['code'] ?? '') as String,
    name: (j['name'] ?? '') as String,
    phone: j['phone'] as String?,
    date: j['date'] as String?,
    dueDate: j['due_date'] as String?,
    total: _d(j['total']),
    paid: _d(j['paid']),
    balance: _d(j['balance']),
    days: (j['days'] as num?)?.toInt() ?? 0,
    overdue: (j['overdue'] as bool?) ?? false,
  );
}

class AgingBucket {
  final String label;
  final double amount;
  AgingBucket({required this.label, required this.amount});
  factory AgingBucket.fromJson(Map<String, dynamic> j) =>
      AgingBucket(label: (j['label'] ?? '') as String, amount: _d(j['amount']));
}

class AccountsReport {
  final double total;
  final int count;
  final List<AgingBucket> aging;
  final List<AccountRow> rows;
  AccountsReport({
    required this.total,
    required this.count,
    required this.aging,
    required this.rows,
  });
  factory AccountsReport.fromJson(Map<String, dynamic> j) => AccountsReport(
    total: _d(j['total']),
    count: (j['count'] as num?)?.toInt() ?? 0,
    aging: ((j['aging'] as List?) ?? [])
        .map((e) => AgingBucket.fromJson(e as Map<String, dynamic>))
        .toList(),
    rows: ((j['rows'] as List?) ?? [])
        .map((e) => AccountRow.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class AccountsReportRepository {
  final ApiClient _api;
  AccountsReportRepository(this._api);

  /// [kind] = receivables | payables. Período "Todo" = todo lo pendiente.
  Future<AccountsReport> get(String kind, ReportPeriod period) async {
    final data = await _api.get('/reports/$kind', query: period.query);
    return AccountsReport.fromJson((data as Map<String, dynamic>)['data']);
  }
}

final accountsReportRepositoryProvider = Provider(
  (ref) => AccountsReportRepository(ref.read(apiClientProvider)),
);

/// Clave "kind#periodKey".
final accountsReportProvider = FutureProvider.family<AccountsReport, String>((
  ref,
  key,
) {
  final i = key.indexOf('#');
  final kind = key.substring(0, i);
  final pk = key.substring(i + 1);
  final period = pk == 'all'
      ? ReportPeriod.of(ReportPreset.all)
      : ReportPeriod(
          ReportPreset.custom,
          DateTime.parse(pk.split('|')[0]),
          DateTime.parse(pk.split('|')[1]),
        );
  return ref.read(accountsReportRepositoryProvider).get(kind, period);
});

String accountsReportKey(String kind, ReportPeriod period) =>
    '$kind#${period.key}';
