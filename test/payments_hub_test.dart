import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/payments/payments_repository.dart';
import 'package:rodex_movil/features/payments/payments_screen.dart';
import 'package:rodex_movil/features/purchases/purchases_repository.dart';
import 'package:rodex_movil/features/workshop/mechanic_payments_repository.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(Ref ref, List<String> permissions)
      : super(ApiClient(), SecureStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'VR MOTORS'),
        companies: [Company(id: 1, name: 'VR MOTORS')],
        permissions: permissions,
        planFeatures: const ['workshop', 'purchases', 'cash'],
      ),
    );
  }
}

/// Cuentas por pagar: dos facturas del mismo proveedor + una de otro.
class _FakePurchases extends PurchasesRepository {
  _FakePurchases() : super(ApiClient());
  @override
  Future<List<DirectPurchaseSummary>> directPurchases({bool unpaid = false}) async => [
        DirectPurchaseSummary(
            id: 1, code: 'COM-00001', supplier: 'Honda Import', date: '2026-07-20',
            daysOld: 53, total: 1000, paidAmount: 0,
            paymentStatus: 'pending', paymentLabel: 'Pendiente'),
        DirectPurchaseSummary(
            id: 2, code: 'COM-00002', supplier: 'Honda Import', date: '2026-09-01',
            daysOld: 10, total: 500, paidAmount: 200,
            paymentStatus: 'partial', paymentLabel: 'Pago parcial'),
        DirectPurchaseSummary(
            id: 3, code: 'COM-00003', supplier: 'Ferretería', date: '2026-09-05',
            daysOld: 6, total: 80, paidAmount: 0,
            paymentStatus: 'pending', paymentLabel: 'Pendiente'),
      ];
}

final _overview = ExpensesOverview(
  monthTotal: 550,
  payrollMonthTotal: 1800,
  services: [
    RecurringService(
        id: 1, name: 'Luz (CRE)', type: 'basico', typeLabel: 'Servicio básico',
        defaultAmount: 350, paidThisMonth: PaymentStamp(date: '2026-09-05', amount: 350)),
    RecurringService(
        id: 2, name: 'Internet (Tigo)', type: 'basico', typeLabel: 'Servicio básico',
        defaultAmount: 200),
  ],
  personal: [
    PersonalRow(id: 4, name: 'Juan Pérez', cargo: 'Mecánico',
        lastPayment: PaymentStamp(date: '2026-08-30', amount: 1800, period: 'Ago 2026')),
    PersonalRow(id: 5, name: 'Ana Rojas', cargo: 'Cajera'),
  ],
  recent: [
    ExpenseMovement(date: '2026-09-05', description: 'Servicio: Luz (CRE) · Sep 2026',
        amount: 350, source: 'Caja'),
  ],
);

Widget _app(List<String> perms) => ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((ref) => _FakeAuth(ref, perms)),
        purchasesRepositoryProvider.overrideWithValue(_FakePurchases()),
        expensesOverviewProvider.overrideWith((ref) async => _overview),
        mechanicPaymentsProvider.overrideWith((ref) async => []),
      ],
      child: const MaterialApp(home: PaymentsScreen()),
    );

void main() {
  testWidgets('Todos los permisos: 4 tabs', (tester) async {
    await tester.pumpWidget(_app(const [
      'mechanic-payments.view', 'accounts-payable.view', 'cash.operate',
    ]));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(4));
    expect(find.text('Mecánicos'), findsOneWidget);
    expect(find.text('Proveedores'), findsOneWidget);
    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Gastos'), findsOneWidget);
  });

  testWidgets('Solo cash.operate: Personal y Gastos, sin Mecánicos ni Proveedores',
      (tester) async {
    await tester.pumpWidget(_app(const ['cash.operate']));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationDestination), findsNWidgets(2));
    expect(find.text('Mecánicos'), findsNothing);
    expect(find.text('Proveedores'), findsNothing);
  });

  testWidgets('Proveedores agrupa por proveedor con subtotal y total',
      (tester) async {
    await tester.pumpWidget(_app(const ['accounts-payable.view', 'cash.operate']));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Proveedores'));
    await tester.pumpAndSettle();

    expect(find.text('Total por pagar'), findsOneWidget);
    expect(find.text('3 facturas · 2 proveedores'), findsOneWidget);
    // Un solo grupo "Honda Import" con 2 facturas (1000 + 300 de saldo = 1300).
    expect(find.text('Honda Import'), findsOneWidget);
    expect(find.textContaining('2 facturas · la más antigua hace 53 días'), findsOneWidget);
    expect(find.text('Ferretería'), findsOneWidget);
  });

  testWidgets('Gastos: servicio pagado y sin pagar muestran su estado del mes',
      (tester) async {
    await tester.pumpWidget(_app(const ['cash.operate']));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Gastos'));
    await tester.pumpAndSettle();

    expect(find.text('Gastos del mes'), findsOneWidget);
    expect(find.text('Luz (CRE)'), findsOneWidget);
    expect(find.textContaining('Pagado 2026-09-05'), findsOneWidget);
    expect(find.text('Internet (Tigo)'), findsOneWidget);
    expect(find.textContaining('Sin pagar este mes'), findsOneWidget);
    expect(find.widgetWithText(FloatingActionButton, 'Otro gasto'), findsOneWidget);
  });

  testWidgets('Personal: muestra último pago y quien no tiene pagos',
      (tester) async {
    await tester.pumpWidget(_app(const ['cash.operate']));
    await tester.pumpAndSettle();

    // Con solo cash.operate el primer tab es Personal.
    expect(find.text('Juan Pérez'), findsOneWidget);
    expect(find.textContaining('(Ago 2026)'), findsOneWidget);
    expect(find.text('Ana Rojas'), findsOneWidget);
    expect(find.textContaining('sin pagos registrados'), findsOneWidget);
  });
}
