import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/reports/reports_screen.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(Ref ref, List<String> permissions, List<String> features)
      : super(ApiClient(), SecureStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'VR MOTORS'),
        companies: [Company(id: 1, name: 'VR MOTORS')],
        permissions: permissions,
        planFeatures: features,
      ),
    );
  }
}

Widget _app(List<String> perms, {List<String> features = const ['sales']}) =>
    ProviderScope(
      overrides: [
        authControllerProvider
            .overrideWith((ref) => _FakeAuth(ref, perms, features)),
      ],
      child: const MaterialApp(home: ReportsScreen()),
    );

void main() {
  testWidgets('Con dashboard y estado de resultados: 2 recuadros',
      (tester) async {
    await tester.pumpWidget(
        _app(const ['sales-dashboard.view', 'income-statement.view']));
    await tester.pumpAndSettle();

    expect(find.text('Análisis'), findsOneWidget);
    expect(find.text('Estado de resultados'), findsOneWidget);
  });

  testWidgets('Solo estado de resultados: 1 recuadro', (tester) async {
    await tester.pumpWidget(_app(const ['income-statement.view']));
    await tester.pumpAndSettle();

    expect(find.text('Análisis'), findsNothing);
    expect(find.text('Estado de resultados'), findsOneWidget);
  });

  testWidgets('Permiso de dashboard sin el módulo en el plan: no hay Análisis',
      (tester) async {
    // Tiene sales-dashboard.view pero el plan NO incluye 'sales'.
    await tester.pumpWidget(
        _app(const ['sales-dashboard.view'], features: const ['workshop']));
    await tester.pumpAndSettle();

    expect(find.text('Análisis'), findsNothing);
    expect(find.textContaining('No hay reportes'), findsOneWidget);
  });
}
