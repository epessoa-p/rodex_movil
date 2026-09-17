import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/company_logo.dart';
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
  }) => AuthState(
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
    : super(const AuthState.loading()) {
    // Cualquier 401 (sesión vencida, usuario desactivado, token revocado)
    // cierra la sesión y deja el motivo para que el login lo muestre.
    _api.onUnauthorized = _onSessionLost;
  }

  /// Motivo del último cierre de sesión forzado (lo consume LoginScreen).
  String? sessionLostMessage;

  /// Última vez que la app estuvo en primer plano (para re-validar al volver).
  DateTime _lastActive = DateTime.now();

  Future<void> _onSessionLost(ApiException e) async {
    if (state.status == AuthStatus.unauthenticated) return;
    sessionLostMessage = switch (e.code) {
      'user_inactive' =>
        'Tu usuario fue desactivado. Contacta al administrador.',
      'session_expired' => e.message,
      _ => 'Tu sesión expiró. Vuelve a ingresar.',
    };
    await _clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
    _resetSessionData();
  }

  /// Llamar al volver del segundo plano: si pasó más de [idle] sin usar la
  /// app, re-valida el token con /me en silencio (si murió, cae al login ya,
  /// no al primer botón que toque). Llamar también al pasar a segundo plano
  /// con [paused] = true para anotar la hora.
  Future<void> onAppLifecycle({
    required bool paused,
    Duration idle = const Duration(minutes: 30),
  }) async {
    if (paused) {
      _lastActive = DateTime.now();
      return;
    }
    if (state.status != AuthStatus.authenticated) return;
    if (DateTime.now().difference(_lastActive) < idle) return;
    _lastActive = DateTime.now();
    try {
      await _api.get('/me');
    } on ApiException {
      // Un 401 ya cerró sesión vía onUnauthorized; otros errores se ignoran.
    }
  }

  /// Limpia los datos cacheados de la sesión anterior (caja, resumen del día,
  /// carrito) para que al cambiar de usuario/empresa no se muestren stale.
  void _resetSessionData() {
    clearCompanyLogoCache();
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
      final data =
          await _api.post(
                '/login',
                body: {
                  'email': email,
                  'password': password,
                  'device': 'app-android',
                },
              )
              as Map<String, dynamic>;

      final token = data['token'] as String;
      await _store.saveToken(token);
      _api.setSession(token: token);

      final companies = ((data['companies'] as List?) ?? [])
          .map((e) => Company.fromJson(e as Map<String, dynamic>))
          .toList();

      if (companies.length == 1) {
        await selectCompany(companies.first.id);
      } else {
        state = AuthState(
          status: AuthStatus.needsCompany,
          companies: companies,
        );
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
      state = AuthState(status: AuthStatus.authenticated, me: me);
      // Logo para los PDF: se descarga y reduce una vez, en segundo plano.
      unawaited(prefetchCompanyLogo(me.company?.logoUrl));
    } on ApiException catch (e) {
      if (e.isUnauthorized) {
        await _clear();
        state = const AuthState(status: AuthStatus.unauthenticated);
      } else if (e.needsCompany) {
        final companies = ((e.data?['companies'] as List?) ?? [])
            .map((c) => Company.fromJson(c as Map<String, dynamic>))
            .toList();
        state = AuthState(
          status: AuthStatus.needsCompany,
          companies: companies,
        );
      } else {
        state = AuthState(status: AuthStatus.unauthenticated, error: e.message);
      }
    }
  }

  /// Recarga `me` sin resetear la sesión (tras editar datos de la empresa).
  Future<void> refreshMe() async {
    if (state.status != AuthStatus.authenticated) return;
    try {
      final data = await _api.get('/me') as Map<String, dynamic>;
      final me = MeContext.fromJson(data);
      setCurrencySymbol(me.company?.currency);
      state = AuthState(status: AuthStatus.authenticated, me: me);
      unawaited(prefetchCompanyLogo(me.company?.logoUrl));
    } on ApiException {
      // Silencioso: mantiene el estado actual si falla.
    }
  }

  Future<void> logout() async {
    try {
      await _api.post('/logout');
    } catch (_) {
      /* best-effort */
    }
    await _clear();
    state = const AuthState(status: AuthStatus.unauthenticated);
    _resetSessionData();
  }

  /// Cambia la contraseña del usuario. Lanza [ApiException] si el backend la
  /// rechaza (p. ej. la contraseña actual no coincide).
  Future<void> changePassword(String current, String nueva) async {
    await _api.post(
      '/change-password',
      body: {
        'current_password': current,
        'password': nueva,
        'password_confirmation': nueva,
      },
    );
  }

  Future<void> _clear() async {
    _api.clearSession();
    await _store.clear();
  }
}
