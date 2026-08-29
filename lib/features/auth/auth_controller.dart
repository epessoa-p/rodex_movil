import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/storage.dart';
import '../pos/cart.dart';
import '../pos/pos_repository.dart';
import '../treasury/treasury_repository.dart';
import '../workshop/workshop_repository.dart';

enum AuthStatus { loading, unauthenticated, needsCompany, authenticated }

class AuthState {
  final AuthStatus status;
  final MeContext? me;
  final List<Company> companies; // opciones cuando status == needsCompany
  final String? error;

  const AuthState({
    required this.status,
    this.me,
    this.companies = const [],
    this.error,
  });

  const AuthState.loading() : this(status: AuthStatus.loading);

  AuthState copyWith({
    AuthStatus? status,
    MeContext? me,
    List<Company>? companies,
    String? error,
  }) =>
      AuthState(
        status: status ?? this.status,
        me: me ?? this.me,
        companies: companies ?? this.companies,
        error: error,
      );
}

/// Maneja el ciclo de sesión: bootstrap (token guardado), login, selección de
/// empresa y logout. Reutiliza el ApiClient para inyectar token + X-Company-Id.
class AuthController extends StateNotifier<AuthState> {
  final ApiClient _api;
  final SecureStore _store;
  final Ref _ref;

  AuthController(this._api, this._store, this._ref)
      : super(const AuthState.loading());

  /// Limpia los datos cacheados de la sesión anterior (caja, resumen del día,
  /// carrito) para que al cambiar de usuario/empresa no se muestren stale.
  void _resetSessionData() {
    _ref.invalidate(cashSessionProvider);
    _ref.invalidate(todaySummaryProvider);
    _ref.invalidate(workOrdersSummaryProvider);
    _ref.invalidate(treasuryAccountsProvider);
    _ref.read(cartProvider.notifier).clear();
  }

  /// Al iniciar la app: si hay token guardado, intenta restaurar la sesión.
  Future<void> bootstrap() async {
    final token = await _store.readToken();
    if (token == null) {
      state = const AuthState(status: AuthStatus.unauthenticated);
      return;
    }
    _api.setSession(token: token);
    final companyId = await _store.readCompanyId();
    if (companyId != null) _api.setCompany(companyId);

    await _loadMe();
  }

  Future<void> login(String email, String password) async {
    state = const AuthState.loading();
    try {
      final data = await _api.post('/login', body: {
        'email': email,
        'password': password,
        'device': 'app-android',
      }) as Map<String, dynamic>;

      final token = data['token'] as String;
      await _store.saveToken(token);
      _api.setSession(token: token);

      final companies = ((data['companies'] as List?) ?? [])
          .map((e) => Company.fromJson(e as Map<String, dynamic>))
          .toList();

      if (companies.length == 1) {
        await selectCompany(companies.first.id);
      } else {
        state = AuthState(status: AuthStatus.needsCompany, companies: companies);
      }
    } on ApiException catch (e) {
      state = AuthState(status: AuthStatus.unauthenticated, error: e.message);
    }
  }

  Future<void> selectCompany(int companyId) async {
    _api.setCompany(companyId);
    await _store.saveCompanyId(companyId);
    await _loadMe();
  }

  Future<void> _loadMe() async {
    try {
      final data = await _api.get('/me') as Map<String, dynamic>;
      final me = MeContext.fromJson(data);
      // Moneda por empresa: ajusta el formateo de precios/totales de la app.
      setCurrencySymbol(me.company?.currency);
      // Nueva sesión/empresa: descarta los datos cacheados del usuario anterior.
      _resetSessionData();
      state = AuthState(
        status: AuthStatus.authenticated,
        me: me,
      );
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _clear();
        state = const AuthState(status: AuthStatus.unauthenticated);
      } else if (e.needsCompany) {
        final companies = ((e.data?['companies'] as List?) ?? [])
            .map((c) => Company.fromJson(c as Map<String, dynamic>))
            .toList();
        state = AuthState(status: AuthStatus.needsCompany, companies: companies);
      } else {
        state = AuthState(status: AuthStatus.unauthenticated, error: e.message);
      }
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/logout');
    } catch (_) {/* best-effort */}
    await _clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
    _resetSessionData();
  }

  Future<void> _clear() async {
    _api.clearSession();
    await _store.clear();
  }
}
