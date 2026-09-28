import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/theme.dart';
import 'package:rodex_movil/features/inventory/catalogs_repository.dart';
import 'package:rodex_movil/features/inventory/moto_models_field.dart';
import 'package:rodex_movil/features/pos/pos_repository.dart';
import 'package:rodex_movil/features/products/new_product_screen.dart';

class _FakePos extends PosRepository {
  _FakePos() : super(ApiClient());
  Map<String, dynamic>? sent;

  @override
  Future<ProductCatalogs> productFormData() async => ProductCatalogs(
    categories: [IdName(id: 1, name: 'LUBRICANTES')],
    brands: [IdName(id: 2, name: 'MOTUL')],
    warehouses: [IdName(id: 9, name: 'ALMACÉN CENTRAL')],
    units: const ['LITRO', 'PAR', 'UNIDAD'],
    defaultUnit: 'UNIDAD',
  );

  @override
  Future<Product> createProduct({
    required String name,
    required double price,
    double? cost,
    String? unit,
    String? barcode,
    int? categoryId,
    int? brandId,
    double? initialStock,
    int? warehouseId,
    String? photoPath,
    String? code,
    String? description,
    int? minStock,
    List<int> motoModelIds = const [],
  }) async {
    sent = {
      'name': name,
      'price': price,
      'cost': cost,
      'unit': unit,
      'code': code,
      'barcode': barcode,
      'min_stock': minStock,
      'moto_models': motoModelIds,
      'initial_stock': initialStock,
      'warehouse_id': warehouseId,
    };
    return Product(id: 77, name: name, price: price, currentStock: 0);
  }
}

class _FakeCatalogs extends CatalogsRepository {
  _FakeCatalogs() : super(ApiClient());

  @override
  Future<List<CatalogItem>> list(CatalogType type, {String q = ''}) async => [
    const CatalogItem(id: 1, name: 'CG 150', brand: 'HONDA', engineCc: '150'),
    const CatalogItem(id: 2, name: 'XR 190', brand: 'HONDA', year: 2022),
    const CatalogItem(id: 3, name: 'VIEJO', brand: 'HONDA', active: false),
  ];
}

Widget _app(_FakePos pos, {bool hideStock = false}) => ProviderScope(
  overrides: [
    posRepositoryProvider.overrideWithValue(pos),
    catalogsRepositoryProvider.overrideWithValue(_FakeCatalogs()),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: NewProductScreen(hideInitialStock: hideStock),
  ),
);

Future<void> _phone(WidgetTester tester) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// La lista es perezosa: lo que está abajo no existe hasta desplazarse.
/// `scrollUntilVisible` para en cuanto el widget se construye (aún bajo el
/// borde); `ensureVisible` lo trae a la vista para poder tocarlo.
Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    250,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Guardar vacío marca los campos obligatorios en línea', (
    tester,
  ) async {
    await _phone(tester);
    final pos = _FakePos();
    await tester.pumpWidget(_app(pos));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Guardar producto'));
    await tester.pumpAndSettle();

    expect(find.text('Escribe el nombre del producto'), findsOneWidget);
    expect(find.text('Indica el precio de venta'), findsOneWidget);
    expect(pos.sent, isNull);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Alta completa: envía código, stock mínimo y modelos', (
    tester,
  ) async {
    await _phone(tester);
    final pos = _FakePos();
    await tester.pumpWidget(_app(pos));
    await tester.pumpAndSettle();

    // Todas las secciones existen (y no desbordan a 360 dp).
    expect(find.text('Precios'), findsOneWidget);
    expect(find.text('Identificación'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre del producto *'),
      'aceite 20w50',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Precio de venta *'),
      '50',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Precio de compra'),
      '30',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Código de referencia'),
      '15400-kwb',
    );

    // Modelos compatibles: se elige uno en la hoja (el inactivo no aparece).
    await _scrollTo(tester, find.byType(MotoModelsField));
    await tester.tap(find.byType(MotoModelsField));
    await tester.pumpAndSettle();
    expect(find.text('VIEJO'), findsNothing);
    await tester.tap(find.text('CG 150'));
    await tester.pumpAndSettle();
    expect(find.text('Listo · 1 modelo'), findsOneWidget);
    await tester.tap(find.text('Listo · 1 modelo'));
    await tester.pumpAndSettle();
    expect(find.text('HONDA CG 150'), findsOneWidget);

    await _scrollTo(tester, find.widgetWithText(TextField, 'Stock mínimo'));
    await tester.enterText(find.widgetWithText(TextField, 'Stock mínimo'), '3');
    // Una sola bodega: se informa, no se pide elegir.
    expect(find.textContaining('se guarda en ALMACÉN CENTRAL'), findsOneWidget);

    await tester.tap(find.text('Guardar producto'));
    await tester.pumpAndSettle();

    expect(pos.sent, isNotNull);
    expect(pos.sent!['name'], 'ACEITE 20W50');
    expect(pos.sent!['price'], 50);
    expect(pos.sent!['cost'], 30);
    expect(pos.sent!['code'], '15400-KWB');
    expect(pos.sent!['unit'], 'UNIDAD');
    expect(pos.sent!['min_stock'], 3);
    expect(pos.sent!['moto_models'], [1]);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Avisa si el precio de compra supera al de venta', (
    tester,
  ) async {
    await _phone(tester);
    await tester.pumpWidget(_app(_FakePos()));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'Precio de venta *'),
      '10',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Precio de compra'),
      '20',
    );
    await tester.pump();

    expect(find.textContaining('¿Los escribiste al revés?'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Desde una compra no pide stock inicial', (tester) async {
    await _phone(tester);
    await tester.pumpWidget(_app(_FakePos(), hideStock: true));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.widgetWithText(TextField, 'Stock mínimo'));
    expect(find.widgetWithText(TextField, 'Stock inicial'), findsNothing);
    expect(find.widgetWithText(TextField, 'Stock mínimo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
