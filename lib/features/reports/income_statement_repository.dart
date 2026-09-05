import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';

/// Una línea del estado de resultados (categoría → monto).
class StatementLine {
  final String label;
  final double amount;
  StatementLine({required this.label, required this.amount});
  factory StatementLine.fromJson(Map<String, dynamic> j) => StatementLine(
        label: (j['label'] ?? '') as String,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
      );
}

/// Estado de resultados por movimientos (caja + tesorería).
class IncomeStatement {
  final String from;
  final String to;
  final List<StatementLine> income;
  final List<StatementLine> expense;
  final double totalIncome;
  final double totalExpense;
  final double net;

  IncomeStatement({
    required this.from,
    required this.to,
    required this.income,
    required this.expense,
    required this.totalIncome,
    required this.totalExpense,
    required this.net,
  });

  factory IncomeStatement.fromJson(Map<String, dynamic> j) => IncomeStatement(
        from: (j['from'] ?? '') as String,
        to: (j['to'] ?? '') as String,
        income: ((j['income'] as List?) ?? [])
            .map((e) => StatementLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        expense: ((j['expense'] as List?) ?? [])
            .map((e) => StatementLine.fromJson(e as Map<String, dynamic>))
            .toList(),
        totalIncome: (j['total_income'] as num?)?.toDouble() ?? 0,
        totalExpense: (j['total_expense'] as num?)?.toDouble() ?? 0,
        net: (j['net'] as num?)?.toDouble() ?? 0,
      );
}

class IncomeStatementRepository {
  final ApiClient _api;
  IncomeStatementRepository(this._api);

  Future<IncomeStatement> get(String from, String to) async {
    final data = await _api
        .get('/income-statement', query: {'from': from, 'to': to});
    return IncomeStatement.fromJson((data as Map<String, dynamic>)['data']);
  }
}

final incomeStatementRepositoryProvider = Provider<IncomeStatementRepository>(
  (ref) => IncomeStatementRepository(ref.read(apiClientProvider)),
);

/// Estado de resultados por rango "from|to" (YYYY-MM-DD|YYYY-MM-DD).
final incomeStatementProvider =
    FutureProvider.family<IncomeStatement, String>((ref, key) {
  final parts = key.split('|');
  return ref.read(incomeStatementRepositoryProvider).get(parts[0], parts[1]);
});
