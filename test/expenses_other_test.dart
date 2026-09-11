import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/payments/expenses_tab.dart';
import 'package:rodex_movil/features/payments/payments_repository.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(Ref ref) : super(ApiClient(), SecureStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'VR MOTORS'),
        companies: [Company(id: 1, name: 'VR MOTORS')],
        permissions: const ['cash.operate'],
        planFeatures: const ['cash'],
      ),
    );
  }
}

void main() {
  _treasuryTests();
  testWidgets('Gastos → "Otro gasto" sin servicios abre la hoja', (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
        expensesOverviewProvider.overrideWith((ref) async => ExpensesOverview(
              monthTotal: 0, payrollMonthTotal: 0,
              services: [], personal: [], recent: [],
            )),
      ],
      child: const MaterialApp(home: Scaffold(body: ExpensesTab())),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Otro gasto'));
    await tester.pumpAndSettle();

    final ex = tester.takeException();
    expect(ex, isNull, reason: 'Excepción al abrir la hoja: $ex');
    expect(find.text('Registrar gasto'), findsOneWidget);
  });
}

class _FakeAuthTreasury extends AuthController {
  _FakeAuthTreasury(Ref ref) : super(ApiClient(), SecureStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'VR MOTORS'),
        companies: [Company(id: 1, name: 'VR MOTORS')],
        permissions: const ['cash.operate', 'treasury.view'],
        planFeatures: const ['cash', 'purchases'],
      ),
    );
  }
}

void _treasuryTests() {
  testWidgets('Con treasury.view: cambiar a Tesorería no rompe la hoja',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((ref) => _FakeAuthTreasury(ref)),
        expensesOverviewProvider.overrideWith((ref) async => ExpensesOverview(
              monthTotal: 0, payrollMonthTotal: 0,
              services: [], personal: [], recent: [],
            )),
      ],
      child: const MaterialApp(home: Scaffold(body: ExpensesTab())),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FloatingActionButton, 'Otro gasto'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Caja'), findsOneWidget);

    await tester.tap(find.text('Tesorería'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
