import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';

/// Cuenta de tesorería (efectivo o banco) con su saldo.
class TreasuryAccount {
  final int id;
  final String name;
  final String type; // cash | bank
  final String typeLabel;
  final String? bankName;
  final String? accountNumber;
  final double balance;
  final bool active;

  TreasuryAccount({
    required this.id,
    required this.name,
    required this.type,
    required this.typeLabel,
    this.bankName,
    this.accountNumber,
    required this.balance,
    required this.active,
  });

  factory TreasuryAccount.fromJson(Map<String, dynamic> j) => TreasuryAccount(
        id: j['id'] as int,
        name: (j['name'] ?? '') as String,
        type: (j['type'] ?? 'cash') as String,
        typeLabel: (j['type_label'] ?? '') as String,
        bankName: j['bank_name'] as String?,
        accountNumber: j['account_number'] as String?,
        balance: (j['balance'] as num?)?.toDouble() ?? 0,
        active: (j['active'] as bool?) ?? true,
      );
}

/// Movimiento de una cuenta (ingreso o gasto).
class TreasuryMovement {
  final int id;
  final String type; // in | out
  final String category;
  final String categoryLabel;
  final double amount;
  final String? description;
  final String? user;
  final String? date;

  TreasuryMovement({
    required this.id,
    required this.type,
    required this.category,
    required this.categoryLabel,
    required this.amount,
    this.description,
    this.user,
    this.date,
  });

  bool get isIncome => type == 'in';

  factory TreasuryMovement.fromJson(Map<String, dynamic> j) => TreasuryMovement(
        id: j['id'] as int,
        type: (j['type'] ?? 'in') as String,
        category: (j['category'] ?? '') as String,
        categoryLabel: (j['category_label'] ?? '') as String,
        amount: (j['amount'] as num?)?.toDouble() ?? 0,
        description: j['description'] as String?,
        user: j['user'] as String?,
        date: j['date'] as String?,
      );
}

/// Listado de cuentas + saldo total (para la pantalla de tesorería).
class TreasuryOverview {
  final double totalBalance;
  final List<TreasuryAccount> accounts;
  TreasuryOverview({required this.totalBalance, required this.accounts});

  factory TreasuryOverview.fromJson(Map<String, dynamic> j) => TreasuryOverview(
        totalBalance: (j['total_balance'] as num?)?.toDouble() ?? 0,
        accounts: ((j['accounts'] as List?) ?? [])
            .map((e) => TreasuryAccount.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Detalle de una cuenta con sus últimos movimientos.
class TreasuryAccountDetail {
  final TreasuryAccount account;
  final List<TreasuryMovement> movements;
  TreasuryAccountDetail({required this.account, required this.movements});

  factory TreasuryAccountDetail.fromJson(Map<String, dynamic> j) =>
      TreasuryAccountDetail(
        account: TreasuryAccount.fromJson(j),
        movements: ((j['movements'] as List?) ?? [])
            .map((e) => TreasuryMovement.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class TreasuryRepository {
  final ApiClient _api;
  TreasuryRepository(this._api);

  Future<TreasuryOverview> accounts() async {
    final data = await _api.get('/treasury/accounts');
    return TreasuryOverview.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<TreasuryAccountDetail> account(int id) async {
    final data = await _api.get('/treasury/accounts/$id');
    return TreasuryAccountDetail.fromJson(
        (data as Map<String, dynamic>)['data']);
  }

  Future<TreasuryAccount> createAccount({
    required String name,
    required String type, // cash | bank
    String? bankName,
    String? accountNumber,
    double? openingBalance,
  }) async {
    final data = await _api.post('/treasury/accounts', body: {
      'name': name,
      'type': type,
      'bank_name': ?bankName,
      'account_number': ?accountNumber,
      'opening_balance': ?openingBalance,
    });
    return TreasuryAccount.fromJson((data as Map<String, dynamic>)['data']);
  }

  /// Registra un ingreso o gasto en la cuenta. Devuelve la cuenta actualizada.
  /// `category`: capital_injection | adjustment_in (ingreso) · expense | adjustment_out (gasto).
  Future<TreasuryAccount> addMovement(
    int accountId, {
    required String category,
    required double amount,
    String? description,
  }) async {
    final data = await _api.post('/treasury/accounts/$accountId/movements', body: {
      'category': category,
      'amount': amount,
      'description': ?description,
    });
    final d = (data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return TreasuryAccount.fromJson(d['account'] as Map<String, dynamic>);
  }
}

final treasuryRepositoryProvider = Provider<TreasuryRepository>(
  (ref) => TreasuryRepository(ref.read(apiClientProvider)),
);

/// Cuentas de tesorería + saldo total (pantalla de tesorería).
final treasuryAccountsProvider = FutureProvider<TreasuryOverview>(
  (ref) => ref.read(treasuryRepositoryProvider).accounts(),
);

/// Detalle de una cuenta (con movimientos).
final treasuryAccountProvider =
    FutureProvider.family<TreasuryAccountDetail, int>(
  (ref, id) => ref.read(treasuryRepositoryProvider).account(id),
);
