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
import 'package:rodex_movil/features/products/product_detail_screen.dart';
import 'package:rodex_movil/features/products/products_screen.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(Ref ref) : super(ApiClient(), SecureStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'VR MOTORS'),
        companies: [Company(id: 1, name: 'VR MOTORS')],
        permissions: const ['products.view', 'products.edit'],
        planFeatures: const ['inventory'],
      ),
    );
  }
}

Product _p({double stock = 4, String? location = 'PA5-VI2'}) =>
    Product.fromJson({
      'id': 1,
      'name': 'PASTILLAS DE FRENO DELANTERAS PARA MOTO',
      'sku': 'PRD-00001',
      'code': 'FR-120',
      'price': 120,
      'current_stock': stock,
      'unit': 'Unidad',
      'brand': 'BOSCH',
      'category': 'FRENOS',
      'models_text': 'CG 150, PULSAR 200, XR 250 TORNADO, CB 190R',
      'location': location,
    });

ProductDetail _detail({String? central, String? norte}) =>
    ProductDetail.fromJson({
      'id': 3,
      'name': 'ACEITE 20W50',
      'sku': 'P-0003',
      'price': 45,
      'current_stock': 10,
      'cost': 30,
      'active': true,
      'stock_by_warehouse': [
        {'id': 10, 'warehouse': 'CENTRAL', 'qty': 10, 'location': central},
        {'id': 20, 'warehouse': 'NORTE', 'qty': 0, 'location': norte},
      ],
      'photos': [],
    });

class _FakePos extends PosRepository {
  Map<int, String>? sent;
  ProductDetail current = _detail(central: 'PA5-VI2');
  _FakePos() : super(ApiClient());

  @override
  Future<ProductDetail> productDetail(int id) async => current;

  @override
  Future<ProductCatalogs> productFormData() async => ProductCatalogs(
    categories: const [],
    brands: const [],
    warehouses: [
      IdName(id: 10, name: 'CENTRAL'),
      IdName(id: 20, name: 'NORTE'),
    ],
  );

  @override
  Future<ProductDetail> updateProduct(
    int id, {
    required String name,
    required double price,
    double? cost,
    String? unit,
    String? barcode,
    String? description,
    int? minStock,
    int? categoryId,
    int? brandId,
    bool active = true,
    String? code,
    List<int>? motoModelIds,
    Map<int, String>? locations,
  }) async {
    sent = locations;
    current = _detail(central: locations?[10], norte: locations?[20]);
    return current;
  }
}

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
}

Widget _tile(Product p, List<String> fields, {bool alwaysStock = false}) =>
    MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: ListTile(
          title: Text(p.name),
          subtitle: ProductInfoLines(
            product: p,
            fields: fields,
            alwaysStock: alwaysStock,
          ),
          trailing: const Text('Bs 120,00'),
        ),
      ),
    );

void main() {
  test(
    'Company: sin pos_card_fields usa el defecto; con lista, la respeta',
    () {
      expect(Company.fromJson({'id': 1, 'name': 'X'}).posCardFields, [
        'code',
        'brand',
        'models',
        'location',
      ]);
      expect(
        Company.fromJson({
          'id': 1,
          'name': 'X',
          'pos_card_fields': ['stock'],
        }).posCardFields,
        ['stock'],
      );
    },
  );

  testWidgets('POS por defecto: código, marca, modelos y ubicación', (
    tester,
  ) async {
    await _phone(tester);
    await tester.pumpWidget(_tile(_p(), Company.posCardDefault));
    expect(tester.takeException(), isNull);
    expect(find.textContaining('FR-120  ·  BOSCH  ·  CG 150'), findsOneWidget);
    expect(find.text('PA5-VI2'), findsOneWidget);
    expect(find.byIcon(Icons.place), findsOneWidget);
    expect(find.textContaining('FRENOS'), findsNothing);
    expect(find.textContaining('Stock'), findsNothing);
  });

  testWidgets('Sin stock se avisa aunque no se haya elegido el stock', (
    tester,
  ) async {
    await _phone(tester);
    await tester.pumpWidget(_tile(_p(stock: 0), Company.posCardDefault));
    expect(find.text('Sin stock'), findsOneWidget);
  });

  testWidgets('Solo ubicación y stock: sin línea de código/marca', (
    tester,
  ) async {
    await _phone(tester);
    await tester.pumpWidget(_tile(_p(), const ['location', 'stock']));
    expect(tester.takeException(), isNull);
    expect(find.text('PA5-VI2'), findsOneWidget);
    expect(find.text('Stock: 4 Unidad'), findsOneWidget);
    expect(find.textContaining('BOSCH'), findsNothing);
  });

  testWidgets('Inventario: el stock siempre; sin ubicación no hay ícono', (
    tester,
  ) async {
    await _phone(tester);
    await tester.pumpWidget(
      _tile(_p(location: null), const ['code'], alwaysStock: true),
    );
    expect(find.text('Stock: 4 Unidad'), findsOneWidget);
    expect(find.byIcon(Icons.place), findsNothing);
  });

  testWidgets('Ficha: ubicación por almacén y edición de ubicaciones', (
    tester,
  ) async {
    await _phone(tester);
    final repo = _FakePos();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
          posRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ProductDetailScreen(
            productId: 3,
            productName: 'ACEITE 20W50',
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(find.text('CENTRAL'), 200);
    expect(find.text('PA5-VI2'), findsOneWidget);

    await tester.tap(find.byTooltip('Editar producto'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final norte = find.widgetWithText(TextField, 'Ubicación en NORTE');
    await tester.scrollUntilVisible(
      norte,
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(
      tester
          .widget<TextField>(
            find.widgetWithText(TextField, 'Ubicación en CENTRAL'),
          )
          .controller!
          .text,
      'PA5-VI2',
    );
    await tester.enterText(norte, 'est3');
    await tester.enterText(
      find.widgetWithText(TextField, 'Ubicación en CENTRAL'),
      '',
    );
    await tester.ensureVisible(find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(repo.sent, {10: '', 20: 'EST3'});
    // El aviso de "actualizado" se cierra solo.
    await tester.pump(const Duration(seconds: 6));
  });
}
