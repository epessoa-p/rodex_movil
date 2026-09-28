import 'dart:convert';

import 'package:flutter/foundation.dart';
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
import 'package:rodex_movil/features/products/product_edit_sheet.dart';
import 'package:rodex_movil/features/products/product_photo.dart';
import 'package:rodex_movil/features/products/products_screen.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(Ref ref, List<String> permissions)
    : super(ApiClient(), SecureStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'VR MOTORS'),
        companies: [Company(id: 1, name: 'VR MOTORS')],
        permissions: permissions,
        planFeatures: const ['inventory', 'sales'],
      ),
    );
  }
}

/// PNG de 1x1 para no tocar la red en los tests.
final _pixel = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// Cuenta qué miniaturas se piden (con las fotos apagadas debe quedar en cero).
class _Loader {
  final List<String> asked = [];
  Future<Uint8List?> call(String url) async {
    asked.add(url);
    return _pixel;
  }
}

/// Preferencia "mostrar fotos" en memoria.
class _FakeStore extends SecureStore {
  _FakeStore({this.show = true});
  bool show;
  int saves = 0;

  @override
  Future<bool> readShowProductPhotos() async => show;

  @override
  Future<void> saveShowProductPhotos(bool value) async {
    show = value;
    saves++;
  }
}

class _FakePos extends PosRepository {
  _FakePos() : super(ApiClient());
  int removed = 0;

  @override
  Future<ProductPage> productsPage({
    String q = '',
    int page = 1,
    int perPage = 30,
  }) async => ProductPage(
    items: [
      Product(
        id: 1,
        name: 'ACEITE 20W50 MOTOR CUATRO TIEMPOS PARA MOTO',
        sku: 'PRD-00001',
        unit: 'LITRO',
        price: 45,
        currentStock: 12,
      ),
      Product(
        id: 2,
        name: 'CADENA 428H',
        sku: 'PRD-00002',
        unit: 'UNIDAD',
        price: 120,
        currentStock: 3,
        imageUrl: 'https://rodex.test/storage/cadena.jpg',
      ),
    ],
    page: 1,
    lastPage: 1,
    total: 2,
  );

  @override
  Future<ProductCatalogs> productFormData() async => ProductCatalogs(
    categories: const [],
    brands: const [],
    warehouses: const [],
  );

  @override
  Future<ProductDetail> removeProductPhoto(int id) async {
    removed++;
    return ProductDetail(
      id: id,
      name: 'CADENA 428H',
      price: 120,
      currentStock: 3,
      compatibleModels: const [],
      stockByWarehouse: const [],
    );
  }
}

Widget _app(
  _FakePos repo,
  Widget home, {
  List<String>? permissions,
  _Loader? loader,
  _FakeStore? store,
}) => ProviderScope(
  overrides: [
    authControllerProvider.overrideWith(
      (ref) => _FakeAuth(
        ref,
        permissions ?? const ['products.view', 'products.edit'],
      ),
    ),
    posRepositoryProvider.overrideWithValue(repo),
    thumbLoaderProvider.overrideWithValue((loader ?? _Loader()).call),
    secureStoreProvider.overrideWithValue(store ?? _FakeStore()),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: home),
);

/// Borde del recuadro de la miniatura de la fila [i] (rojo = sin foto).
BorderSide _borde(WidgetTester tester, int i) {
  final box = tester
      .widgetList<Container>(
        find.descendant(
          of: find.byType(ProductThumb).at(i),
          matching: find.byType(Container),
        ),
      )
      .first;
  return ((box.decoration as BoxDecoration).border as Border).top;
}

void main() {
  testWidgets('El listado muestra miniatura y la foto se cambia de un toque', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _FakePos();
    await tester.pumpWidget(_app(repo, const ProductsScreen()));
    await tester.pumpAndSettle();

    // Una miniatura por fila; el distintivo distingue cuál tiene foto.
    expect(find.byType(ProductThumb), findsNWidgets(2));
    expect(find.byIcon(Icons.photo_camera), findsOneWidget); // CADENA (tiene)
    expect(find.byIcon(Icons.add_a_photo), findsOneWidget); // ACEITE (falta)
    expect(_borde(tester, 0).color.r, greaterThan(0.6)); // sin foto: rojo
    expect(_borde(tester, 1).color.r, lessThan(0.2)); // con foto: gris

    // Producto sin foto: el atajo ofrece agregarla.
    await tester.tap(find.byType(ProductThumb).first);
    await tester.pumpAndSettle();
    expect(find.text('Agregar foto'), findsOneWidget);
    expect(find.text('Tomar foto'), findsOneWidget);
    expect(find.text('Elegir de la galería'), findsOneWidget);
    expect(find.text('Quitar foto'), findsNothing);

    Navigator.of(tester.element(find.text('Tomar foto'))).pop();
    await tester.pumpAndSettle();

    // Producto con foto: además permite quitarla, y se llama al backend.
    await tester.tap(find.byType(ProductThumb).last);
    await tester.pumpAndSettle();
    expect(find.text('Cambiar foto'), findsOneWidget);
    await tester.tap(find.text('Quitar foto'));
    await tester.pumpAndSettle();

    expect(repo.removed, 1);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Sin permiso de edición la miniatura no invita a cambiarla', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _app(
        _FakePos(),
        const ProductsScreen(),
        permissions: const ['products.view'],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProductThumb), findsNWidgets(2));
    expect(find.byIcon(Icons.photo_camera), findsNothing);
    expect(find.byIcon(Icons.add_a_photo), findsNothing);
    await tester.tap(find.byType(ProductThumb).first);
    await tester.pumpAndSettle();
    expect(find.text('Tomar foto'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('La hoja de edición tiene el campo de foto', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final product = ProductDetail(
      id: 7,
      name: 'FILTRO DE ACEITE',
      sku: 'PRD-00007',
      price: 35,
      currentStock: 4,
      compatibleModels: const [],
      stockByWarehouse: const [],
    );

    await tester.pumpWidget(
      _app(_FakePos(), Scaffold(body: ProductEditSheet(product: product))),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ProductThumb), findsOneWidget);
    expect(find.text('Agregar foto'), findsOneWidget);
    expect(find.text('La foto se guarda al elegirla.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('Con fotos encendidas se piden las miniaturas por la caché', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final loader = _Loader();
    await tester.pumpWidget(
      _app(_FakePos(), const ProductsScreen(), loader: loader),
    );
    await tester.pumpAndSettle();

    // Solo el producto con foto genera descarga; el otro ni la pide.
    expect(loader.asked, ['https://rodex.test/storage/cadena.jpg']);
    expect(find.byType(Image), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('El interruptor apaga las fotos: cero descargas y se recuerda', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final loader = _Loader();
    final store = _FakeStore();
    await tester.pumpWidget(
      _app(_FakePos(), const ProductsScreen(), loader: loader, store: store),
    );
    await tester.pumpAndSettle();
    expect(loader.asked.length, 1);

    await tester.tap(find.byTooltip('Ocultar fotos'));
    await tester.pumpAndSettle();

    // Ninguna imagen pintada y nada más pedido a la red.
    expect(find.byType(Image), findsNothing);
    expect(loader.asked.length, 1);
    // Pero se sigue viendo cuál tiene foto y cuál no.
    expect(find.byIcon(Icons.photo_camera), findsOneWidget);
    expect(find.byIcon(Icons.add_a_photo), findsOneWidget);
    expect(_borde(tester, 0).color.r, greaterThan(0.6));
    expect(store.show, isFalse);
    expect(store.saves, 1);

    // El atajo para cambiar la foto sigue disponible.
    await tester.tap(find.byType(ProductThumb).last);
    await tester.pumpAndSettle();
    expect(find.text('Tomar foto'), findsOneWidget);
    Navigator.of(tester.element(find.text('Tomar foto'))).pop();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('La preferencia guardada (apagado) se respeta al abrir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final loader = _Loader();
    await tester.pumpWidget(
      _app(
        _FakePos(),
        const ProductsScreen(),
        loader: loader,
        store: _FakeStore(show: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byTooltip('Mostrar fotos'), findsOneWidget);
    expect(find.byType(Image), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });
}
