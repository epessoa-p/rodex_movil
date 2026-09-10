import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/pos/pos_repository.dart';
import 'package:rodex_movil/features/pos/pos_screen.dart';

class _FakePosRepository extends PosRepository {
  _FakePosRepository() : super(ApiClient());

  @override
  Future<List<Product>> products({String q = ''}) async => [
        Product(
            id: 1,
            name: 'Filtro de aceite',
            sku: 'PRD-00001',
            unit: 'unidad',
            price: 48.5,
            currentStock: 3),
      ];
}

void main() {
  testWidgets('POS: "Agregar" abre el selector y agregar no rompe la vista',
      (tester) async {
    await tester.pumpWidget(ProviderScope(
      overrides: [
        posRepositoryProvider.overrideWithValue(_FakePosRepository()),
        authControllerProvider.overrideWith(
            (ref) => AuthController(ApiClient(), SecureStore(), ref)),
        // Caja abierta, para que el POS muestre el carrito y no el aviso.
        cashSessionProvider.overrideWith((ref) async => CashSession(
              id: 1,
              cashRegister: 'Caja 1',
              branch: 'AMERICAS',
              openingAmount: 0,
              totalIncome: 0,
              totalExpense: 0,
              expectedAmount: 0,
            )),
      ],
      child: const MaterialApp(home: PosScreen()),
    ));
    await tester.pumpAndSettle();

    // Abrir el selector de productos.
    await tester.tap(find.widgetWithText(OutlinedButton, 'Agregar'));
    await tester.pumpAndSettle();

    expect(find.text('Agregar producto'), findsOneWidget);
    expect(find.text('Filtro de aceite'), findsOneWidget);
    expect(find.text('Carrito vacío'), findsOneWidget);

    // Agregar el producto: la lista debe seguir viva y el footer actualizarse.
    await tester.tap(find.text('Filtro de aceite'));
    await tester.pumpAndSettle();

    expect(find.text('Filtro de aceite'), findsOneWidget);
    expect(find.textContaining('1 ítem'), findsOneWidget);
  });
}
