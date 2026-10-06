import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/theme.dart';
import 'package:rodex_movil/features/purchases/po_receive_screen.dart';
import 'package:rodex_movil/features/purchases/purchases_repository.dart';

class _FakeRepo extends PurchasesRepository {
  _FakeRepo(this.status, {this.editable = true}) : super(ApiClient());
  String status;
  final bool editable;
  Map<String, dynamic>? sent;

  @override
  Future<PoDetail> orderDetail(int id) async => PoDetail(
    id: id,
    code: 'OC-00009',
    supplier: 'Honda Import',
    supplierId: 4,
    status: status,
    notes: 'URGENTE',
    editable: editable,
    discount: 10,
    total: 290,
    items: [
      PoItem(
        poItemId: 1,
        productId: 21,
        product: 'FILTRO DE ACEITE',
        ordered: 3,
        received: 0,
        pending: 3,
        unitCost: 100,
      ),
    ],
    warehouses: [WarehouseOption(id: 1, name: 'Principal')],
  );

  // El proveedor de la OC no está en la lista (inactivo): no debe fallar.
  @override
  Future<List<Supplier>> suppliers({String q = ''}) async => [
    Supplier(id: 3, name: 'Yamaha SRL'),
  ];

  @override
  Future<PoSummary> updatePurchaseOrder(
    int id, {
    required int supplierId,
    required List<Map<String, dynamic>> items,
    required String status,
    String? expectedDate,
    String? notes,
    double discount = 0,
  }) async {
    sent = {
      'id': id,
      'supplier_id': supplierId,
      'items': items,
      'status': status,
      'notes': notes,
      'discount': discount,
    };
    this.status = status;
    return PoSummary(
      id: id,
      code: 'OC-00009',
      status: status,
      statusLabel: status,
      total: 290,
    );
  }
}

Future<void> _pump(WidgetTester t, _FakeRepo repo) async {
  t.view.physicalSize = const Size(360, 640);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    ProviderScope(
      overrides: [purchasesRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: const PoReceiveScreen(orderId: 9, code: 'OC-00009'),
      ),
    ),
  );
  await t.pumpAndSettle();
}

void main() {
  testWidgets('borrador: se ve, se edita y se marca como Enviada', (t) async {
    final repo = _FakeRepo('draft');
    await _pump(t, repo);

    // El borrador no se recibe todavía, pero se puede editar.
    expect(find.textContaining('márcala como Enviada'), findsOneWidget);
    expect(find.text('Recibir y sumar al stock'), findsNothing);
    await t.tap(find.byTooltip('Editar orden'));
    await t.pumpAndSettle();

    // Formulario precargado.
    expect(find.text('Editar OC-00009'), findsOneWidget);
    expect(find.text('Honda Import'), findsOneWidget);
    expect(find.text('FILTRO DE ACEITE'), findsOneWidget);
    expect(find.text('URGENTE'), findsOneWidget);
    expect(
      t
          .widget<TextField>(find.byKey(const Key('discount_amount')))
          .controller!
          .text,
      '10.00',
    );

    // Cambiar la cantidad tocando la línea.
    await t.tap(find.text('FILTRO DE ACEITE'));
    await t.pumpAndSettle();
    final dialogFields = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    );
    await t.enterText(dialogFields.first, '5');
    await t.tap(find.text('Guardar'));
    await t.pumpAndSettle();

    await t.tap(find.text('Enviada'));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('Guardar cambios'),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ListView).last,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await t.pumpAndSettle();
    await t.tap(find.text('Guardar cambios'));
    await t.pumpAndSettle();

    expect(repo.sent!['status'], 'sent');
    expect(repo.sent!['supplier_id'], 4);
    expect(repo.sent!['discount'], 10);
    expect(repo.sent!['notes'], 'URGENTE');
    final items = repo.sent!['items'] as List;
    expect(items.single['product_id'], 21);
    expect(items.single['quantity'], 5);

    // De vuelta en el detalle, ya enviada: se puede recibir.
    expect(find.text('Recibir y sumar al stock'), findsOneWidget);
    expect(find.textContaining('actualizada'), findsOneWidget);
    expect(t.takeException(), isNull);
    // Deja que el aviso se cierre solo (su temporizador).
    await t.pump(const Duration(seconds: 10));
    await t.pumpAndSettle();
  });

  testWidgets('recibida: sin botón de editar', (t) async {
    await _pump(t, _FakeRepo('received', editable: false));
    expect(find.byTooltip('Editar orden'), findsNothing);
    expect(find.textContaining('ya no admite recepciones'), findsOneWidget);
  });
}
