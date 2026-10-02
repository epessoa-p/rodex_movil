import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/core/theme.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/pos/cart.dart';
import 'package:rodex_movil/features/pos/pos_repository.dart';
import 'package:rodex_movil/features/pos/pos_screen.dart';
import 'package:rodex_movil/features/products/products_screen.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(Ref ref) : super(ApiClient(), SecureStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'TALLER'),
        companies: [Company(id: 1, name: 'TALLER')],
        permissions: const ['pos.access', 'sales.create', 'products.view'],
        planFeatures: const ['sales'],
      ),
    );
  }
}

class _FakePos extends PosRepository {
  _FakePos() : super(ApiClient());
  List<Map<String, dynamic>>? sentItems;

  @override
  Future<ProductPage> productsPage({
    String q = '',
    int page = 1,
    int perPage = 30,
  }) async => ProductPage(
    // Con búsqueda no encuentra nada (para probar la oferta de venta rápida).
    items: q.isEmpty
        ? [Product(id: 1, name: 'FILTRO', price: 20, currentStock: 5)]
        : const [],
    page: 1,
    lastPage: 1,
    total: q.isEmpty ? 1 : 0,
  );

  @override
  Future<Sale> createSale({
    int? clientId,
    required List<Map<String, dynamic>> items,
    double discount = 0,
    String method = 'efectivo',
  }) async {
    sentItems = items;
    throw ApiException('detenido en el test');
  }
}

CashSession _open() => CashSession(
  id: 1,
  cashRegister: 'Caja 1',
  openingAmount: 0,
  totalIncome: 0,
  totalExpense: 0,
  expectedAmount: 0,
);

Widget _pos(_FakePos repo) => ProviderScope(
  overrides: [
    posRepositoryProvider.overrideWithValue(repo),
    authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
    cashSessionProvider.overrideWith((ref) async => _open()),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: const PosScreen()),
);

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  test('El carrito arma el ítem de venta rápida como el POS web', () {
    final cart = Cart();
    cart.addDirect(name: 'EMPAQUE', price: 25, quantity: 2);
    cart.addDirect(name: 'TORNILLO', price: 1.5);

    expect(cart.state.map((l) => l.product.id).toSet().length, 2);
    expect(cart.state.every((l) => l.direct && l.product.id < 0), isTrue);
    expect(cart.total, 51.5);
    expect(cart.toItems().first, {
      'direct': 1,
      'name': 'EMPAQUE',
      'quantity': 2.0,
      'unit_price': 25.0,
      'discount': 0.0,
    });
  });

  testWidgets('POS: botón Rápida → hoja → al carrito → se envía como directo', (
    tester,
  ) async {
    await _phone(tester);
    final repo = _FakePos();
    await tester.pumpWidget(_pos(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rápida'));
    await tester.pumpAndSettle();
    expect(find.text('Venta rápida'), findsOneWidget);

    // Vacío: avisa en los campos, no agrega nada.
    await tester.tap(find.text('Agregar al carrito'));
    await tester.pumpAndSettle();
    expect(find.text('Escribe qué estás vendiendo'), findsOneWidget);
    expect(find.text('Indica el precio'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Producto *'),
      'empaque de motor',
    );
    await tester.enterText(find.widgetWithText(TextField, 'Precio *'), '25');
    await tester.tap(find.byTooltip('Más'));
    await tester.pumpAndSettle();
    expect(find.text('Bs 50.00'), findsOneWidget); // total de la línea en vivo

    await tester.tap(find.text('Agregar al carrito'));
    await tester.pumpAndSettle();

    // En el carrito, con su marca.
    expect(find.text('EMPAQUE DE MOTOR'), findsOneWidget);
    expect(find.text('Venta rápida'), findsOneWidget);

    await tester.tap(find.text('Cobrar'));
    await tester.pumpAndSettle();
    expect(repo.sentItems, [
      {
        'direct': 1,
        'name': 'EMPAQUE DE MOTOR',
        'quantity': 2.0,
        'unit_price': 25.0,
        'discount': 0.0,
      },
    ]);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Buscador sin resultados ofrece la venta rápida con lo escrito', (
    tester,
  ) async {
    await _phone(tester);
    String? offered;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          posRepositoryProvider.overrideWithValue(_FakePos()),
          authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: ProductsScreen(onPick: (_) {}, onQuickSale: (n) => offered = n),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'cadena 428');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();

    expect(find.text('«cadena 428» no está en el inventario.'), findsOneWidget);
    await tester.tap(find.text('Venta rápida'));
    expect(offered, 'cadena 428');
    expect(tester.takeException(), isNull);
  });
}
