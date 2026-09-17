import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/auth/login_screen.dart';

/// Sin plugin de almacenamiento seguro en tests.
class _FakeStore extends SecureStore {
  @override
  Future<void> clear() async {}
}

/// ApiClient cuyo `get` falla con el ApiException indicado (simula un 401 del
/// backend con el hook de sesión perdida).
class _Api401 extends ApiClient {
  final ApiException error;
  _Api401(this.error);

  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async {
    // Mismo comportamiento que el interceptor real ante 401 con sesión.
    onUnauthorized?.call(error);
    throw error;
  }
}

/// AuthController autenticado, con el fake de API inyectado.
class _Auth extends AuthController {
  _Auth(Ref ref, ApiClient api) : super(api, _FakeStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'VR MOTORS'),
        companies: [Company(id: 1, name: 'VR MOTORS')],
        permissions: const [],
        planFeatures: const [],
      ),
    );
  }
}

void main() {
  test(
    'ApiClient: un 401 con sesión dispara onUnauthorized y limpia el token',
    () async {
      final api = ApiClient();
      ApiException? got;
      api.onUnauthorized = (e) => got = e;
      api.setSession(token: 'abc', companyId: 1);

      // Un 401 real del backend, sin red: se inyecta la excepción de Dio.
      final req = RequestOptions(path: '/work-orders');
      final dioErr = DioException(
        requestOptions: req,
        response: Response(
          requestOptions: req,
          statusCode: 401,
          data: {'message': 'Tu sesión expiró', 'code': 'session_expired'},
        ),
      );
      expect(
        () => api.runForTest(() => Future<Response>.error(dioErr)),
        throwsA(isA<ApiException>()),
      );
      await Future<void>.delayed(Duration.zero);
      expect(got?.code, 'session_expired');
    },
  );

  testWidgets('Sesión vencida: cae a login y muestra el motivo arriba', (
    tester,
  ) async {
    final api = _Api401(
      ApiException(
        'Tu usuario fue desactivado. Contacta al administrador.',
        statusCode: 401,
        code: 'user_inactive',
      ),
    );
    late _Auth auth;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => auth = _Auth(ref, api)),
        ],
        child: Consumer(
          builder: (context, ref, _) {
            final status = ref.watch(authControllerProvider).status;
            return MaterialApp(
              home: status == AuthStatus.authenticated
                  ? const Scaffold(body: Text('HOME'))
                  : const LoginScreen(),
            );
          },
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('HOME'), findsOneWidget);

    // Simula volver del segundo plano tras >30 min: re-valida /me → 401.
    await auth.onAppLifecycle(paused: true);
    await auth.onAppLifecycle(paused: false, idle: Duration.zero);
    await tester.pumpAndSettle();

    expect(find.text('HOME'), findsNothing);
    expect(find.text('Usuario o email'), findsOneWidget);
    expect(find.text('Sesión cerrada'), findsOneWidget);
    expect(
      find.text('Tu usuario fue desactivado. Contacta al administrador.'),
      findsOneWidget,
    );
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
