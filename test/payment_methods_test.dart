import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/payment_methods.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/core/theme.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/cash/cash_screen.dart';
import 'package:rodex_movil/features/pos/cart.dart';
import 'package:rodex_movil/features/pos/pos_repository.dart';
import 'package:rodex_movil/features/pos/pos_screen.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(Ref ref, List<String> methods)
    : super(ApiClient(), SecureStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'TALLER', paymentMethods: methods),
        companies: [Company(id: 1, name: 'TALLER')],
        permissions: const ['pos.access', 'sales.create', 'cash.operate'],
        planFeatures: const ['sales', 'cash'],
      ),
    );
  }
}

class _FakePos extends PosRepository {
  _FakePos() : super(ApiClient());
  String? sentMethod;

  @override
  Future<Sale> createSale({
    int? clientId,
    required List<Map<String, dynamic>> items,
    double discount = 0,
    String method = 'efectivo',
  }) async {
    sentMethod = method;
    // Que no navegue al recibo: basta con saber qué se envió.
    throw ApiException('detenido en el test');
  }

  @override
  Future<List<CashMovement>> sessionMovements() async => [
    CashMovement(id: 1, type: 'income', category: 'Venta', amount: 100),
    CashMovement(
      id: 2,
      type: 'income',
      category: 'Venta',
      amount: 100,
      method: 'qr',
    ),
  ];
}

final _filtro = Product(
  id: 1,
  name: 'FILTRO DE ACEITE',
  price: 48.5,
  currentStock: 3,
);

CashSession _session({List<MethodAmount> other = const []}) => CashSession(
  id: 1,
  cashRegister: 'Caja 1',
  branch: 'AMERICAS',
  openingAmount: 0,
  totalIncome: 200,
  totalExpense: 0,
  cashIncome: 100,
  cashExpense: 0,
  expectedAmount: 100,
  otherMethods: other,
  availableAmount: 200,
);

Widget _pos(_FakePos repo, List<String> methods) {
  final container = ProviderContainer(
    overrides: [
      posRepositoryProvider.overrideWithValue(repo),
      authControllerProvider.overrideWith((ref) => _FakeAuth(ref, methods)),
      cashSessionProvider.overrideWith((ref) async => _session()),
    ],
  );
  container.read(cartProvider.notifier).add(_filtro);
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: AppTheme.light(), home: const PosScreen()),
  );
}

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  testWidgets('POS con QR habilitado: chips y la venta se envía con QR', (
    tester,
  ) async {
    await _phone(tester);
    final repo = _FakePos();
    await tester.pumpWidget(_pos(repo, normalizePaymentMethods(['qr'])));
    await tester.pumpAndSettle();

    expect(find.byType(PaymentMethodChips), findsOneWidget);
    expect(find.text('Efectivo'), findsOneWidget);
    expect(find.text('Cobrar · Efectivo'), findsOneWidget);

    await tester.tap(find.widgetWithText(ChoiceChip, 'QR'));
    await tester.pumpAndSettle();
    expect(find.text('Cobrar · QR'), findsOneWidget);

    await tester.tap(find.text('Cobrar · QR'));
    await tester.pumpAndSettle();
    expect(repo.sentMethod, 'qr');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('POS solo efectivo: sin chips, botón "Cobrar" de siempre', (
    tester,
  ) async {
    await _phone(tester);
    final repo = _FakePos();
    await tester.pumpWidget(_pos(repo, const ['efectivo']));
    await tester.pumpAndSettle();

    expect(find.byType(ChoiceChip), findsNothing);
    await tester.tap(find.text('Cobrar'));
    await tester.pumpAndSettle();
    expect(repo.sentMethod, 'efectivo');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Caja: esperado solo en efectivo y el QR aparte', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          posRepositoryProvider.overrideWithValue(_FakePos()),
          authControllerProvider.overrideWith(
            (ref) => _FakeAuth(ref, const ['efectivo', 'qr']),
          ),
          cashSessionProvider.overrideWith(
            (ref) async => _session(
              other: const [
                MethodAmount(method: 'qr', label: 'QR', amount: 100),
              ],
            ),
          ),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const CashScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Esperado en el cajón'), findsOneWidget);
    expect(
      find.text('Otros medios — no se cuentan en el cajón'),
      findsOneWidget,
    );
    // El movimiento por QR dice su método.
    await tester.scrollUntilVisible(
      find.text('Venta · QR'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Venta · QR'), findsOneWidget);

    // El cierre compara solo con el efectivo y avisa que el QR no se cuenta.
    await tester.scrollUntilVisible(
      find.text('Cerrar caja'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Cerrar caja'));
    await tester.pumpAndSettle();
    expect(find.text('Efectivo esperado'), findsOneWidget);
    expect(find.text('No los cuentes: no están en el cajón'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('Lista de la empresa: efectivo siempre, primero y sin desconocidos', () {
    expect(normalizePaymentMethods(null), ['efectivo']);
    expect(normalizePaymentMethods(['tarjeta', 'qr', 'bitcoin']), [
      'efectivo',
      'qr',
      'tarjeta',
    ]);
    expect(isCashMethod(null), isTrue);
    expect(paymentMethodLabel('transferencia'), 'Transferencia');
  });
}
