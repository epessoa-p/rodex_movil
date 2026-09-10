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

class _FakePosRepository extends PosRepository {
  _FakePosRepository() : super(ApiClient());

  @override
  Future<List<Product>> products({String q = ''}) async => [
        Product(
            id: 1,
            name: 'Filtro de aceite Honda CG 150',
            sku: 'PRD-00001',
            unit: 'unidad',
            price: 48.5,
            currentStock: 3),
        Product(
            id: 2,
            name: 'Bujía NGK',
            sku: 'PRD-00002',
            unit: 'unidad',
            price: 25,
            currentStock: 0),
      ];
}

Widget _wrap(Widget child) => ProviderScope(
      overrides: [
        posRepositoryProvider.overrideWithValue(_FakePosRepository()),
        authControllerProvider
            .overrideWith((ref) => AuthController(ApiClient(), SecureStore(), ref)),
      ],
      child: MaterialApp(home: child),
    );

void main() {
  testWidgets('La lista en modo selección (POS) renderiza los productos',
      (tester) async {
    await tester.pumpWidget(_wrap(ProductsScreen(onPick: (_) {})));
    await tester.pumpAndSettle();

    expect(find.text('Agregar producto'), findsOneWidget);
    expect(find.text('Filtro de aceite Honda CG 150'), findsOneWidget);
    expect(find.text('Bujía NGK'), findsOneWidget);
  });

  testWidgets('Tocar un producto lo entrega vía onPick (sin abrir la ficha)',
      (tester) async {
    final picked = <Product>[];
    await tester.pumpWidget(_wrap(ProductsScreen(onPick: picked.add)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Filtro de aceite Honda CG 150'));
    await tester.pumpAndSettle();

    expect(picked, hasLength(1));
    expect(picked.single.id, 1);
  });

  testWidgets('Sin stock no se agrega y avisa (requireStock)', (tester) async {
    final picked = <Product>[];
    await tester.pumpWidget(_wrap(ProductsScreen(onPick: picked.add)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bujía NGK')); // currentStock = 0
    await tester.pumpAndSettle();

    expect(picked, isEmpty);
    expect(find.textContaining('sin stock disponible'), findsOneWidget);
  });
}
