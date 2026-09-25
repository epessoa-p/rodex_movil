import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/core/theme.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/pos/pos_repository.dart';
import 'package:rodex_movil/features/pos/sales_history_screen.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(Ref ref) : super(ApiClient(), SecureStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'VR MOTORS'),
        companies: [Company(id: 1, name: 'VR MOTORS')],
        permissions: const ['sales.view', 'pos.access'],
        planFeatures: const ['sales'],
      ),
    );
  }
}

class _FakePos extends PosRepository {
  _FakePos() : super(ApiClient());

  @override
  Future<SalesPage> sales({
    int page = 1,
    String q = '',
    String? dateFrom,
    String? dateTo,
  }) async => SalesPage(
    page: 1,
    hasMore: false,
    items: [
      Sale.fromJson({
        'id': 1,
        'code': 'V-00001',
        'sale_type': 'credit',
        'sale_date': '2026-09-22T10:00:00',
        'client': 'ANA ROJAS',
        'total': 500,
        'paid_amount': 200,
        'balance': 300,
        'payment_status': 'partial', // la API responde en inglés
      }),
      Sale.fromJson({
        'id': 2,
        'code': 'V-00002',
        'sale_type': 'cash',
        'sale_date': '2026-09-22T11:00:00',
        'client': 'JUAN PAZ',
        'total': 120,
        'paid_amount': 120,
        'balance': 0,
        'payment_status': 'paid',
      }),
    ],
  );
}

void main() {
  testWidgets('Ventas: estado en español, con color y saldo del crédito', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
          posRepositoryProvider.overrideWithValue(_FakePos()),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const SalesHistoryScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Nada de "partial"/"paid" crudos.
    expect(find.text('partial'), findsNothing);
    expect(find.text('paid'), findsNothing);
    expect(find.text('Parcial'), findsOneWidget);
    expect(find.text('Pagada'), findsOneWidget);

    // Crédito con saldo pendiente.
    expect(find.text('Crédito'), findsOneWidget);
    expect(find.text('Saldo Bs 300.00'), findsOneWidget);

    // Color: parcial naranja, pagada verde.
    final parcial = tester.widget<Text>(find.text('Parcial'));
    expect(parcial.style!.color, Colors.orange);
    final pagada = tester.widget<Text>(find.text('Pagada'));
    expect(pagada.style!.color, Colors.green);
    expect(tester.takeException(), isNull);
  });
}
