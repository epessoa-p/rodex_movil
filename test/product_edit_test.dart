import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/pos/pos_repository.dart';
import 'package:rodex_movil/features/products/product_detail_screen.dart';

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

ProductDetail _detail({String name = 'ACEITE 20W50', double price = 45}) =>
    ProductDetail.fromJson({
      'id': 3,
      'name': name,
      'sku': 'P-0003',
      'price': price,
      'current_stock': 10,
      'cost': 30,
      'min_stock': 2,
      'category_id': 1,
      'brand_id': null,
      'active': true,
      'stock_by_warehouse': [
        {'id': 1, 'warehouse': 'CENTRAL', 'qty': 10},
      ],
      'photos': [],
    });

class _FakePos extends PosRepository {
  final updates = <Map<String, dynamic>>[];
  _FakePos() : super(ApiClient());

  @override
  Future<ProductDetail> productDetail(int id) async => _detail();

  @override
  Future<ProductCatalogs> productFormData() async => ProductCatalogs(
    categories: [IdName(id: 1, name: 'LUBRICANTES')],
    brands: [IdName(id: 5, name: 'CASTROL')],
    warehouses: [IdName(id: 1, name: 'CENTRAL')],
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
  }) async {
    updates.add({'name': name, 'price': price, 'cost': cost, 'brand': brandId});
    return _detail(name: name, price: price);
  }
}

void main() {
  testWidgets(
    'Editar producto: hoja precargada, cambia precio y refresca la ficha',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakePos();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
            posRepositoryProvider.overrideWithValue(repo),
          ],
          child: const MaterialApp(
            home: ProductDetailScreen(
              productId: 3,
              productName: 'ACEITE 20W50',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Editar producto'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Editar producto'), findsOneWidget);
      // Precargado.
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Precio *'))
            .controller!
            .text,
        '45.00',
      );
      expect(find.text('LUBRICANTES'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Precio *'),
        '52.5',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();

      expect(repo.updates.single['price'], 52.5);
      expect(repo.updates.single['name'], 'ACEITE 20W50');
      expect(find.text('Producto actualizado.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    },
  );
}
