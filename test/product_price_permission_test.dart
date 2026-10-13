import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/core/theme.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/inventory/catalogs_repository.dart';
import 'package:rodex_movil/features/pos/pos_repository.dart';
import 'package:rodex_movil/features/products/product_edit_sheet.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(Ref ref, List<String> permissions)
    : super(ApiClient(), SecureStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 3, name: 'Vendedor'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'TALLER'),
        companies: [Company(id: 1, name: 'TALLER')],
        permissions: permissions,
        planFeatures: const ['inventory'],
      ),
    );
  }
}

class _FakePos extends PosRepository {
  _FakePos() : super(ApiClient());

  @override
  Future<ProductCatalogs> productFormData() async => const ProductCatalogs(
    categories: [],
    brands: [],
    warehouses: [],
    units: ['UNIDAD'],
    defaultUnit: 'UNIDAD',
  );
}

class _FakeCatalogs extends CatalogsRepository {
  _FakeCatalogs() : super(ApiClient());

  @override
  Future<List<CatalogItem>> list(CatalogType type, {String q = ''}) async =>
      const [];
}

ProductDetail _detail() => ProductDetail.fromJson({
  'id': 8,
  'name': 'CASCO LS2',
  'sku': 'PRD-00008',
  'unit': 'UNIDAD',
  'price': 500,
  'cost': 300,
  'current_stock': 4,
  'min_stock': 0,
  'active': true,
  'stock_by_warehouse': [],
  'photos': [],
});

Future<void> _pump(WidgetTester t, List<String> perms) async {
  t.view.physicalSize = const Size(360, 640);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((ref) => _FakeAuth(ref, perms)),
        posRepositoryProvider.overrideWithValue(_FakePos()),
        catalogsRepositoryProvider.overrideWithValue(_FakeCatalogs()),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(body: ProductEditSheet(product: _detail())),
      ),
    ),
  );
  await t.pumpAndSettle();
}

bool _readOnly(WidgetTester t, String key) =>
    t.widget<TextField>(find.byKey(Key(key))).readOnly;

void main() {
  testWidgets('sin "Cambiar precios": precio y costo bloqueados', (t) async {
    await _pump(t, const ['products.edit']);
    expect(_readOnly(t, 'edit_price'), isTrue);
    expect(_readOnly(t, 'edit_cost'), isTrue);
    expect(
      find.text('No tienes permiso para cambiar precios ni costos.'),
      findsOneWidget,
    );
    expect(find.byIcon(Icons.lock_outline), findsNWidgets(2));
    expect(t.takeException(), isNull);
  });

  testWidgets('con "Cambiar precios": se pueden editar', (t) async {
    await _pump(t, const ['products.edit', 'products.prices']);
    expect(_readOnly(t, 'edit_price'), isFalse);
    expect(_readOnly(t, 'edit_cost'), isFalse);
    expect(
      find.text('No tienes permiso para cambiar precios ni costos.'),
      findsNothing,
    );
  });
}
