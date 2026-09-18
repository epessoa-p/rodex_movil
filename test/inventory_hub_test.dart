import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/inventory/catalog_picker_field.dart';
import 'package:rodex_movil/features/inventory/catalogs_repository.dart';
import 'package:rodex_movil/features/inventory/inventory_hub_screen.dart';
import 'package:rodex_movil/features/pos/pos_repository.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(Ref ref) : super(ApiClient(), SecureStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'VR MOTORS'),
        companies: [Company(id: 1, name: 'VR MOTORS')],
        permissions: const [
          'products.view',
          'products.create',
          'product-categories.view',
          'product-categories.create',
          'product-brands.view',
          'moto-models.view',
          'product-origins.view',
        ],
        planFeatures: const ['inventory'],
      ),
    );
  }
}

/// 75 productos en páginas de 30: prueba el "cargar más".
class _FakePos extends PosRepository {
  _FakePos() : super(ApiClient());
  int pagesRequested = 0;

  @override
  Future<ProductPage> productsPage({
    String q = '',
    int page = 1,
    int perPage = 30,
  }) async {
    pagesRequested++;
    const total = 75;
    final start = (page - 1) * perPage;
    final end = (start + perPage).clamp(0, total);
    return ProductPage(
      items: [
        for (var i = start; i < end; i++)
          Product(
            id: i + 1,
            name: 'PRODUCTO ${i + 1}',
            sku: 'PRD-${i + 1}',
            unit: 'unidad',
            price: 10.0 + i,
            currentStock: 5,
          ),
      ],
      page: page,
      lastPage: (total / perPage).ceil(),
      total: total,
    );
  }
}

class _FakeCatalogs extends CatalogsRepository {
  _FakeCatalogs() : super(ApiClient());
  int listCalls = 0;
  final created = <String>[];

  @override
  Future<List<CatalogItem>> list(CatalogType type, {String q = ''}) async {
    listCalls++;
    return [
      CatalogItem(id: 1, name: 'FRENOS'),
      CatalogItem(id: 2, name: 'LUBRICANTES'),
      const CatalogItem(id: 3, name: 'VIEJA', active: false),
    ];
  }

  @override
  Future<CatalogItem> create(
    CatalogType type, {
    required String name,
    Map<String, dynamic> extra = const {},
  }) async {
    created.add(name);
    return CatalogItem(id: 99, name: name);
  }
}

void main() {
  testWidgets('Hub Inventario: tabs perezosos y paginación de productos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final pos = _FakePos();
    final cats = _FakeCatalogs();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
          posRepositoryProvider.overrideWithValue(pos),
          catalogsRepositoryProvider.overrideWithValue(cats),
        ],
        child: const MaterialApp(home: InventoryHubScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Solo se cargó productos (30 de 75); los catálogos aún no.
    expect(find.text('Inventario'), findsOneWidget);
    expect(find.text('30 de 75 productos'), findsOneWidget);
    expect(pos.pagesRequested, 1);
    expect(cats.listCalls, 0);

    // Al bajar hasta el final se pide la página 2.
    await tester.drag(find.byType(ListView).first, const Offset(0, -6000));
    await tester.pumpAndSettle();
    expect(pos.pagesRequested, greaterThanOrEqualTo(2));
    expect(find.textContaining('de 75 productos'), findsOneWidget);

    // Abrir Categorías: recién ahí se carga ese catálogo.
    await tester.tap(find.text('Categorías'));
    await tester.pumpAndSettle();
    expect(cats.listCalls, 1);
    expect(find.text('FRENOS'), findsOneWidget);
    expect(find.textContaining('inactivo'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Selector de catálogo: buscar y crear «X» si no existe', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final cats = _FakeCatalogs();
    IdName? chosen;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [catalogsRepositoryProvider.overrideWithValue(cats)],
        child: MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => CatalogPickerField(
                label: 'Categoría',
                type: CatalogType.categories,
                options: [IdName(id: 1, name: 'FRENOS')],
                value: chosen?.id,
                onChanged: (v) => setState(() => chosen = v),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Buscar o crear…'));
    await tester.pumpAndSettle();

    // Escribir algo que no existe ofrece crearlo.
    await tester.enterText(find.byType(TextField).last, 'aceites');
    await tester.pumpAndSettle();
    expect(find.text('Crear «ACEITES»'), findsOneWidget);
    await tester.tap(find.text('Crear «ACEITES»'));
    await tester.pumpAndSettle();

    expect(cats.created, ['ACEITES']);
    expect(chosen?.id, 99);
    expect(tester.takeException(), isNull);
  });
}
