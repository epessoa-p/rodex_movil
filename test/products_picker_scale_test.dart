import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/pos/pos_repository.dart';
import 'package:rodex_movil/features/products/products_screen.dart';

/// 50 productos con foto y nombres/precios largos: lo que devuelve el backend real.
class _BigPosRepository extends PosRepository {
  _BigPosRepository() : super(ApiClient());

  @override
  Future<List<Product>> products({String q = ''}) async => List.generate(
        50,
        (i) => Product(
          id: i + 1,
          name: 'Producto de nombre bastante largo para probar el ancho $i',
          sku: 'PRD-${i.toString().padLeft(5, '0')}',
          unit: 'unidad',
          price: 123456.78,
          currentStock: i.isEven ? 5 : 0,
          imageUrl: 'https://rodex.sczsoft.net/storage/company/1/products/$i/f.jpg',
        ),
      );
}

void main() {
  testWidgets('50 productos con foto y textos largos no rompen el layout',
      (tester) async {
    // Pantalla de teléfono típica (360x640 lógicos).
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(ProviderScope(
      overrides: [
        posRepositoryProvider.overrideWithValue(_BigPosRepository()),
        authControllerProvider.overrideWith(
            (ref) => AuthController(ApiClient(), SecureStore(), ref)),
      ],
      child: MaterialApp(home: ProductsScreen(onPick: (_) {})),
    ));
    await tester.pumpAndSettle();

    expect(find.text('Agregar producto'), findsOneWidget);
    // Si hubo overflow/excepción de layout, el test falla aquí.
    expect(tester.takeException(), isNull);

    // Desplazarse por la lista completa.
    await tester.fling(find.byType(ListView), const Offset(0, -3000), 1000);
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
