import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/theme.dart';
import 'package:rodex_movil/features/inventory/catalogs_repository.dart';
import 'package:rodex_movil/features/inventory/moto_models_field.dart';
import 'package:rodex_movil/features/pos/pos_repository.dart';
import 'package:rodex_movil/features/products/product_edit_sheet.dart';

/// Ficha tal como la devuelve GET /products/{id}, con código y modelos.
ProductDetail _detail() => ProductDetail.fromJson({
  'id': 8,
  'name': 'CADENA 428H',
  'sku': 'PRD-00008',
  'code': 'DID-428H',
  'unit': 'JUEGO', // unidad vieja que ya no está en el catálogo
  'price': 120,
  'cost': 80,
  'current_stock': 4,
  'min_stock': 2,
  'active': true,
  'compatible_models': ['HONDA CG 150'],
  'moto_models': [
    {'id': 1, 'name': 'CG 150', 'brand': 'HONDA', 'engine_cc': '150'},
  ],
  'stock_by_warehouse': [],
  'photos': [],
});

class _FakePos extends PosRepository {
  _FakePos() : super(ApiClient());
  Map<String, dynamic>? sent;

  @override
  Future<ProductCatalogs> productFormData() async => const ProductCatalogs(
    categories: [],
    brands: [],
    warehouses: [],
    units: ['LITRO', 'PAR', 'UNIDAD'],
    defaultUnit: 'UNIDAD',
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
  }) async {
    sent = {'code': code, 'unit': unit, 'models': motoModelIds, 'price': price};
    return _detail();
  }
}

class _FakeCatalogs extends CatalogsRepository {
  _FakeCatalogs() : super(ApiClient());

  @override
  Future<List<CatalogItem>> list(CatalogType type, {String q = ''}) async => [
    const CatalogItem(id: 1, name: 'CG 150', brand: 'HONDA'),
    const CatalogItem(id: 2, name: 'GN 125', brand: 'SUZUKI'),
  ];
}

Widget _app(_FakePos pos) => ProviderScope(
  overrides: [
    posRepositoryProvider.overrideWithValue(pos),
    catalogsRepositoryProvider.overrideWithValue(_FakeCatalogs()),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: ProductEditSheet(product: _detail())),
  ),
);

Future<void> _scrollTo(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'Editar: precarga código, unidad vieja y modelos; guarda cambios',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final pos = _FakePos();
      await tester.pumpWidget(_app(pos));
      await tester.pumpAndSettle();

      // Precargado desde la ficha.
      expect(find.text('DID-428H'), findsOneWidget);
      expect(find.text('Precio de venta *'), findsOneWidget);
      expect(find.text('Precio de compra'), findsOneWidget);
      await _scrollTo(tester, find.text('JUEGO'));
      expect(
        find.text('JUEGO'),
        findsOneWidget,
      ); // no se pierde la unidad vieja
      await _scrollTo(tester, find.byType(MotoModelsField));
      expect(find.text('HONDA CG 150'), findsOneWidget);

      // Cambia el código de referencia.
      await _scrollTo(
        tester,
        find.widgetWithText(TextField, 'Código de referencia'),
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Código de referencia'),
        'did-428h-x',
      );

      // Agrega un modelo en la hoja.
      await _scrollTo(tester, find.byType(MotoModelsField));
      await tester.tap(find.byType(MotoModelsField));
      await tester.pumpAndSettle();
      await tester.tap(find.text('GN 125'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Listo · 2 modelos'));
      await tester.pumpAndSettle();
      expect(find.text('SUZUKI GN 125'), findsOneWidget);

      await _scrollTo(tester, find.text('Guardar'));
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(pos.sent, isNotNull);
      expect(pos.sent!['code'], 'DID-428H-X');
      expect(pos.sent!['unit'], 'JUEGO');
      expect(pos.sent!['models'], [1, 2]);
      expect(tester.takeException(), isNull);
      await tester.pump(const Duration(seconds: 5));
    },
  );

  testWidgets('Quitar todos los modelos envía lista vacía (no null)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final pos = _FakePos();
    await tester.pumpWidget(_app(pos));
    await tester.pumpAndSettle();

    await _scrollTo(tester, find.byType(MotoModelsField));
    await tester.tap(find.byTooltip('Quitar'));
    await tester.pumpAndSettle();
    expect(find.text('HONDA CG 150'), findsNothing);

    await _scrollTo(tester, find.text('Guardar'));
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(pos.sent!['models'], isEmpty);
    expect(pos.sent!['models'], isNotNull);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });
}
