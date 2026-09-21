import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import 'report_period.dart';

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

/// Movimiento de caja (ingreso/egreso) del reporte.
class CashMovementRow {
  final int id;
  final DateTime? date;
  final String type; // income | expense
  final String category;
  final String? description;
  final double amount;
  final String? method;
  final String? register;
  final String? branch;
  final String? user;

  CashMovementRow({
    required this.id,
    this.date,
    required this.type,
    required this.category,
    this.description,
    required this.amount,
    this.method,
    this.register,
    this.branch,
    this.user,
  });

  bool get isIncome => type == 'income';

  factory CashMovementRow.fromJson(Map<String, dynamic> j) => CashMovementRow(
    id: j['id'] as int,
    date: j['date'] != null ? DateTime.tryParse(j['date'] as String) : null,
    type: (j['type'] ?? '') as String,
    category: (j['category'] ?? '') as String,
    description: j['description'] as String?,
    amount: _d(j['amount']),
    method: j['method'] as String?,
    register: j['register'] as String?,
    branch: j['branch'] as String?,
    user: j['user'] as String?,
  );
}

/// Cierre (o sesión abierta) de caja.
class CashClosure {
  final int id;
  final String status; // open | closed
  final String? register;
  final String? branch;
  final DateTime? openedAt;
  final DateTime? closedAt;
  final String? openedBy;
  final String? closedBy;
  final double openingAmount;
  final double income;
  final double expense;
  final double expectedAmount;
  final double? closingAmount;
  final double? difference;
  final String? notes;

  CashClosure({
    required this.id,
    required this.status,
    this.register,
    this.branch,
    this.openedAt,
    this.closedAt,
    this.openedBy,
    this.closedBy,
    required this.openingAmount,
    required this.income,
    required this.expense,
    required this.expectedAmount,
    this.closingAmount,
    this.difference,
    this.notes,
  });

  bool get isOpen => status == 'open';

  factory CashClosure.fromJson(Map<String, dynamic> j) => CashClosure(
    id: j['id'] as int,
    status: (j['status'] ?? '') as String,
    register: j['register'] as String?,
    branch: j['branch'] as String?,
    openedAt: j['opened_at'] != null
        ? DateTime.tryParse(j['opened_at'] as String)
        : null,
    closedAt: j['closed_at'] != null
        ? DateTime.tryParse(j['closed_at'] as String)
        : null,
    openedBy: j['opened_by'] as String?,
    closedBy: j['closed_by'] as String?,
    openingAmount: _d(j['opening_amount']),
    income: _d(j['income']),
    expense: _d(j['expense']),
    expectedAmount: _d(j['expected_amount']),
    closingAmount: j['closing_amount'] == null ? null : _d(j['closing_amount']),
    difference: j['difference'] == null ? null : _d(j['difference']),
    notes: j['notes'] as String?,
  );
}

class CategoryTotal {
  final String label;
  final String type;
  final double amount;
  CategoryTotal({
    required this.label,
    required this.type,
    required this.amount,
  });
  factory CategoryTotal.fromJson(Map<String, dynamic> j) => CategoryTotal(
    label: (j['label'] ?? '') as String,
    type: (j['type'] ?? '') as String,
    amount: _d(j['amount']),
  );
}

class CashReport {
  final String from;
  final String to;
  final double income;
  final double expense;
  final double balance;
  final List<CategoryTotal> byCategory;
  final List<CashMovementRow> movements;
  final bool truncated;
  final int totalCount;
  final List<CashClosure> closures;
  final List<IdName> branches;

  CashReport({
    required this.from,
    required this.to,
    required this.income,
    required this.expense,
    required this.balance,
    required this.byCategory,
    required this.movements,
    required this.truncated,
    required this.totalCount,
    required this.closures,
    required this.branches,
  });

  factory CashReport.fromJson(Map<String, dynamic> j) {
    final s = (j['summary'] as Map<String, dynamic>?) ?? {};
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List?) ?? [])
            .map((e) => f(e as Map<String, dynamic>))
            .toList();
    return CashReport(
      from: (j['from'] ?? '') as String,
      to: (j['to'] ?? '') as String,
      income: _d(s['income']),
      expense: _d(s['expense']),
      balance: _d(s['balance']),
      byCategory: list('by_category', CategoryTotal.fromJson),
      movements: list('movements', CashMovementRow.fromJson),
      truncated: (j['truncated'] as bool?) ?? false,
      totalCount: (j['total_count'] as int?) ?? 0,
      closures: list('closures', CashClosure.fromJson),
      branches: list('branches', IdName.fromJson),
    );
  }
}

class FinanceReportRepository {
  final ApiClient _api;
  FinanceReportRepository(this._api);

  Future<CashReport> cash(ReportPeriod period, {int? branchId}) async {
    final data = await _api.get(
      '/reports/cash',
      query: {...period.query, 'branch_id': ?branchId},
    );
    return CashReport.fromJson((data as Map<String, dynamic>)['data']);
  }
}

final financeReportRepositoryProvider = Provider(
  (ref) => FinanceReportRepository(ref.read(apiClientProvider)),
);

/// Clave "periodKey|branchId" (branchId vacío = todas las sucursales).
final cashReportProvider = FutureProvider.family<CashReport, String>((
  ref,
  key,
) {
  final parts = key.split('#');
  final period = parts[0] == 'all'
      ? ReportPeriod.of(ReportPreset.all)
      : ReportPeriod(
          ReportPreset.custom,
          DateTime.parse(parts[0].split('|')[0]),
          DateTime.parse(parts[0].split('|')[1]),
        );
  final branchId = parts.length > 1 && parts[1].isNotEmpty
      ? int.tryParse(parts[1])
      : null;
  return ref
      .read(financeReportRepositoryProvider)
      .cash(period, branchId: branchId);
});

String cashReportKey(ReportPeriod period, int? branchId) =>
    '${period.key}#${branchId ?? ''}';
