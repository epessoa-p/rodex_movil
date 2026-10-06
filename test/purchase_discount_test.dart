import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/theme.dart';
import 'package:rodex_movil/features/purchases/purchase_discount_field.dart';
import 'package:rodex_movil/features/purchases/purchases_repository.dart';

/// Padre mínimo: guarda el descuento como lo haría la pantalla de compra.
class _Host extends StatefulWidget {
  final double subtotal;
  const _Host({required this.subtotal});
  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  SupplierDiscount value = const SupplierDiscount.none();
  late double subtotal = widget.subtotal;
  double get discount => value.amountFor(subtotal);
  void setSubtotal(double v) => setState(() => subtotal = v);

  @override
  Widget build(BuildContext context) => Scaffold(
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        PurchaseDiscountField(
          subtotal: subtotal,
          value: value,
          onChanged: (d) => setState(() => value = d),
        ),
        Text('ENVIA ${discount.toStringAsFixed(2)}'),
      ],
    ),
  );
}

class _CaptureApi extends ApiClient {
  Object? body;
  String? path;
  @override
  Future<dynamic> post(String path, {Object? body}) async {
    this.path = path;
    this.body = body;
    return {
      'data': {'id': 1, 'code': 'OC-1', 'status': 'sent', 'total': 135},
    };
  }
}

String _text(WidgetTester t, String key) =>
    t.widget<TextField>(find.byKey(Key(key))).controller!.text;

Future<_HostState> _pump(WidgetTester t, double subtotal) async {
  t.view.physicalSize = const Size(360, 640);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: _Host(subtotal: subtotal),
    ),
  );
  return t.state<_HostState>(find.byType(_Host));
}

void main() {
  test('SupplierDiscount: % y monto, acotado al subtotal', () {
    expect(const SupplierDiscount.percent(10).amountFor(150), 15);
    expect(const SupplierDiscount.amount(20).amountFor(150), 20);
    expect(const SupplierDiscount.amount(999).amountFor(150), 150);
    expect(const SupplierDiscount.percent(-5).amountFor(150), 0);
    expect(const SupplierDiscount.none().amountFor(150), 0);
  });

  testWidgets('descuento en %: calcula monto y total a 360 dp', (t) async {
    final host = await _pump(t, 150);
    expect(_text(t, 'discount_total'), '150.00');

    await t.enterText(find.byKey(const Key('discount_pct')), '10');
    await t.pump();
    expect(host.discount, 15);
    expect(_text(t, 'discount_amount'), '15.00');
    expect(_text(t, 'discount_total'), '135.00');
    expect(find.text('Quitar'), findsOneWidget);

    // El % se mantiene si cambian los productos.
    host.setSubtotal(300);
    await t.pump();
    expect(host.discount, 30);
    expect(_text(t, 'discount_total'), '270.00');
    expect(t.takeException(), isNull);
  });

  testWidgets('descuento en monto: calcula el %', (t) async {
    final host = await _pump(t, 300);
    await t.enterText(find.byKey(const Key('discount_amount')), '20');
    await t.pump();
    expect(host.discount, 20);
    expect(_text(t, 'discount_pct'), '6.67');
    expect(_text(t, 'discount_total'), '280.00');
  });

  testWidgets('total editado: el descuento se calcula solo', (t) async {
    final host = await _pump(t, 400);
    await t.enterText(find.byKey(const Key('discount_total')), '360');
    await t.pump();
    expect(host.discount, 40);
    expect(_text(t, 'discount_pct'), '10');
    expect(_text(t, 'discount_amount'), '40.00');

    // Un total mayor al subtotal no genera descuento y avisa.
    await t.enterText(find.byKey(const Key('discount_total')), '500');
    await t.pump();
    expect(host.discount, 0);
    expect(find.textContaining('no puede ser mayor'), findsOneWidget);

    // Quitar limpia todo.
    await t.enterText(find.byKey(const Key('discount_amount')), '50');
    await t.pump();
    await t.tap(find.text('Quitar'));
    await t.pump();
    expect(host.discount, 0);
    expect(_text(t, 'discount_total'), '400.00');
    expect(t.takeException(), isNull);
  });

  test('el repositorio envía el descuento (OC y compra directa)', () async {
    final api = _CaptureApi();
    final repo = PurchasesRepository(api);
    final items = [
      {'product_id': 1, 'quantity': 1, 'unit_cost': 150.0},
    ];

    await repo.createPurchaseOrder(supplierId: 1, items: items, discount: 15);
    expect(api.path, '/purchase-orders');
    expect((api.body as Map)['discount'], 15);

    await repo.directPurchase(
      supplierId: 1,
      warehouseId: 1,
      items: items,
      discount: 15,
    );
    expect(api.path, '/purchases/direct');
    expect((api.body as Map)['discount'], 15);

    // Sin descuento no se envía el campo.
    await repo.directPurchase(supplierId: 1, warehouseId: 1, items: items);
    expect((api.body as Map).containsKey('discount'), isFalse);
  });

  test('detalle de compra y de OC leen el descuento', () {
    final p = DirectPurchaseDetail.fromJson({
      'id': 1,
      'code': 'COM-1',
      'subtotal': 150,
      'discount': 15,
      'total': 135,
      'paid_amount': 135,
      'payment_label': 'Pagada',
    });
    expect(p.subtotal, 150);
    expect(p.discount, 15);
    final o = PoDetail.fromJson({
      'id': 1,
      'code': 'OC-1',
      'status': 'sent',
      'discount': 10,
      'total': 290,
    });
    expect(o.discount, 10);
  });
}
