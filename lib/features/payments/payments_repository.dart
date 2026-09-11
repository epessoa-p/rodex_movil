import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';

double _d(dynamic v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

/// Un pago ya registrado (fecha + monto [+ período]).
class PaymentStamp {
  final String date;
  final double amount;
  final String? period;
  PaymentStamp({required this.date, required this.amount, this.period});
  factory PaymentStamp.fromJson(Map<String, dynamic> j) => PaymentStamp(
    date: (j['date'] ?? '') as String,
    amount: _d(j['amount']),
    period: j['period'] as String?,
  );
}

/// Servicio recurrente del catálogo (luz, agua, internet…).
class RecurringService {
  final int id;
  final String name;
  final String type; // basico | externo | transporte | otro
  final String typeLabel;
  final double defaultAmount;
  final PaymentStamp? paidThisMonth;

  RecurringService({
    required this.id,
    required this.name,
    required this.type,
    required this.typeLabel,
    required this.defaultAmount,
    this.paidThisMonth,
  });

  factory RecurringService.fromJson(Map<String, dynamic> j) => RecurringService(
    id: j['id'] as int,
    name: (j['name'] ?? '') as String,
    type: (j['type'] ?? 'otro') as String,
    typeLabel: (j['type_label'] ?? '') as String,
    defaultAmount: _d(j['default_amount']),
    paidThisMonth: j['paid_this_month'] == null
        ? null
        : PaymentStamp.fromJson(j['paid_this_month'] as Map<String, dynamic>),
  );
}

/// Personal activo con su último pago.
class PersonalRow {
  final int id;
  final String name;
  final String? cargo;
  final PaymentStamp? lastPayment;
  PersonalRow({
    required this.id,
    required this.name,
    this.cargo,
    this.lastPayment,
  });
  factory PersonalRow.fromJson(Map<String, dynamic> j) => PersonalRow(
    id: j['id'] as int,
    name: (j['name'] ?? '') as String,
    cargo: j['cargo'] as String?,
    lastPayment: j['last_payment'] == null
        ? null
        : PaymentStamp.fromJson(j['last_payment'] as Map<String, dynamic>),
  );
}

/// Un egreso registrado (caja o tesorería).
class ExpenseMovement {
  final int? id;
  final String date;
  final String description;
  final double amount;
  final String source; // 'Caja' o nombre de la cuenta
  ExpenseMovement({
    this.id,
    required this.date,
    required this.description,
    required this.amount,
    required this.source,
  });
  factory ExpenseMovement.fromJson(Map<String, dynamic> j) => ExpenseMovement(
    id: j['id'] as int?,
    date: (j['date'] ?? '') as String,
    description: (j['description'] ?? '') as String,
    amount: _d(j['amount']),
    source: (j['source'] ?? '') as String,
  );
}

class ExpensesOverview {
  final double monthTotal;
  final double payrollMonthTotal;
  final List<RecurringService> services;
  final List<PersonalRow> personal;
  final List<ExpenseMovement> recent;

  ExpensesOverview({
    required this.monthTotal,
    required this.payrollMonthTotal,
    required this.services,
    required this.personal,
    required this.recent,
  });

  factory ExpensesOverview.fromJson(Map<String, dynamic> j) => ExpensesOverview(
    monthTotal: _d(j['month_total']),
    payrollMonthTotal: _d(j['payroll_month_total']),
    services: ((j['services'] as List?) ?? [])
        .map((e) => RecurringService.fromJson(e as Map<String, dynamic>))
        .toList(),
    personal: ((j['personal'] as List?) ?? [])
        .map((e) => PersonalRow.fromJson(e as Map<String, dynamic>))
        .toList(),
    recent: ((j['recent'] as List?) ?? [])
        .map((e) => ExpenseMovement.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}

class PaymentsRepository {
  final ApiClient _api;
  PaymentsRepository(this._api);

  Future<ExpensesOverview> overview() async {
    final data = await _api.get('/expenses/overview');
    return ExpensesOverview.fromJson((data as Map<String, dynamic>)['data']);
  }

  /// [kind] = service | other | transport | payroll; [source] = cash | treasury.
  Future<ExpenseMovement> registerExpense({
    required String kind,
    required double amount,
    required String source,
    int? expenseServiceId,
    int? personalId,
    String? concept,
    String? period,
    int? treasuryAccountId,
    String? notes,
  }) async {
    final data = await _api.post(
      '/expenses',
      body: {
        'kind': kind,
        'amount': amount,
        'payment_source': source,
        'expense_service_id': ?expenseServiceId,
        'personal_id': ?personalId,
        'concept': ?concept,
        'period': ?period,
        'treasury_account_id': ?treasuryAccountId,
        'notes': ?notes,
      },
    );
    return ExpenseMovement.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<RecurringService> createService({
    required String name,
    required String type,
    double? defaultAmount,
  }) async {
    final data = await _api.post(
      '/expense-services',
      body: {'name': name, 'type': type, 'default_amount': ?defaultAmount},
    );
    return RecurringService.fromJson((data as Map<String, dynamic>)['data']);
  }
}

final paymentsRepositoryProvider = Provider<PaymentsRepository>(
  (ref) => PaymentsRepository(ref.read(apiClientProvider)),
);

/// Overview de gastos/personal. autoDispose + invalidate tras cada pago.
final expensesOverviewProvider = FutureProvider.autoDispose<ExpensesOverview>(
  (ref) => ref.read(paymentsRepositoryProvider).overview(),
);
