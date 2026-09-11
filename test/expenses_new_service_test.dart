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
        permissions: const ['cash.operate', 'expense-services.manage'],
        planFeatures: const ['cash'],
      ),
    );
  }
}

void main() {
  testWidgets('Gastos → "Nuevo servicio" abre la hoja sin colgarse',
      (tester) async {
    // Tamaño de teléfono real, para que el overflow del teclado se note.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

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

    expect(find.text('Nuevo servicio'), findsOneWidget);
    await tester.tap(find.text('Nuevo servicio'));
    await tester.pumpAndSettle();

    expect(find.text('Nuevo servicio recurrente'), findsOneWidget);
    expect(tester.takeException(), isNull);

    // Elegir un tipo en el desplegable y escribir: no debe romper el rebuild.
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Transporte').last);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}

