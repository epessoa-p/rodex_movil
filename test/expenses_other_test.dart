import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/app_toast.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/payments/expenses_tab.dart';
import 'package:rodex_movil/features/payments/payments_repository.dart';
import 'package:rodex_movil/features/payments/personal_tab.dart';

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
  _payrollTests();
  _toastTests();
  testWidgets('Gastos → "Otro gasto" sin servicios abre la hoja', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
          expensesOverviewProvider.overrideWith(
            (ref) async => ExpensesOverview(
              monthTotal: 0,
              payrollMonthTotal: 0,
              services: [],
              personal: [],
              recent: [],
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ExpensesTab())),
      ),
    );
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
  testWidgets('Con treasury.view: cambiar a Tesorería no rompe la hoja', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _FakeAuthTreasury(ref)),
          expensesOverviewProvider.overrideWith(
            (ref) async => ExpensesOverview(
              monthTotal: 0,
              payrollMonthTotal: 0,
              services: [],
              personal: [],
              recent: [],
            ),
          ),
        ],
        child: const MaterialApp(home: Scaffold(body: ExpensesTab())),
      ),
    );
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

void _payrollTests() {
  testWidgets(
    'Personal → hoja de pago con selección de período (Día/Semana/Quincena/Mes/Otro)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
            expensesOverviewProvider.overrideWith(
              (ref) async => ExpensesOverview(
                monthTotal: 0,
                payrollMonthTotal: 0,
                services: [],
                recent: [],
                personal: [
                  PersonalRow(
                    id: 4,
                    name: 'Juan Pérez',
                    cargo: 'Mecánico',
                    lastPayment: PaymentStamp(
                      date: '2026-08-30',
                      amount: 1800,
                      period: 'Quincena',
                    ),
                  ),
                ],
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: PersonalTab())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Juan Pérez'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Las 5 opciones como selección, y "Quincena" preseleccionada por el último pago.
      for (final p in ['Día', 'Semana', 'Quincena', 'Mes', 'Otro']) {
        expect(find.widgetWithText(ChoiceChip, p), findsOneWidget);
      }
      final quincena = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, 'Quincena'),
      );
      expect(quincena.selected, isTrue);
      expect(find.text('¿Qué se paga?'), findsNothing);

      // "Otro" muestra el campo para indicar el concepto (bono, adelanto…).
      await tester.tap(find.widgetWithText(ChoiceChip, 'Otro'));
      await tester.pumpAndSettle();
      expect(find.text('¿Qué se paga?'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}

void _toastTests() {
  testWidgets(
    'Con la hoja abierta, el aviso de validación se ve (toast arriba, no SnackBar tapado)',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
            expensesOverviewProvider.overrideWith(
              (ref) async => ExpensesOverview(
                monthTotal: 0,
                payrollMonthTotal: 0,
                services: [],
                personal: [],
                recent: [],
              ),
            ),
          ],
          child: const MaterialApp(home: Scaffold(body: ExpensesTab())),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(FloatingActionButton, 'Otro gasto'));
      await tester.pumpAndSettle();

      // Enviar sin monto ni concepto → aviso de validación.
      await tester.tap(find.text('Registrar gasto'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.byType(SnackBar),
        findsNothing,
      ); // ya no se usa el SnackBar tapado
      expect(find.text('Revisa el formulario'), findsOneWidget);
      expect(find.text('Ingresa un monto mayor a cero.'), findsOneWidget);
      // La hoja sigue abierta debajo del aviso.
      expect(find.text('Otro gasto'), findsWidgets);

      // Se cierra solo.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Revisa el formulario'), findsNothing);
    },
  );

  test('titleForCode mapea los códigos de negocio a títulos claros', () {
    expect(
      AppToast.titleForCode('insufficient_balance'),
      'Fondos insuficientes',
    );
    expect(AppToast.titleForCode('no_open_session'), 'Caja cerrada');
    expect(
      AppToast.titleForCode('amount_exceeds_balance'),
      'Monto mayor al saldo',
    );
    expect(AppToast.titleForCode(null), 'No se pudo completar');
  });
}
