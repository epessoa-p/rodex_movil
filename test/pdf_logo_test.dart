import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/features/pos/receipt_letter_pdf.dart';
import 'package:rodex_movil/features/pos/receipt_screen.dart';
import 'package:rodex_movil/features/workshop/work_order_letter_pdf.dart';
import 'package:rodex_movil/features/workshop/work_order_pdf.dart';

// PNG válido de 8×8 px (rojo), suficiente para incrustarlo en el PDF.
final Uint8List _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAgAAAAICAIAAABLbSncAAAACXBIWXMAAA7EAAAOxAGVKw4bAAAAFElEQVQImWO8IyfHgA0wYRUdtBIA4FYBKNlKVSIAAAAASUVORK5CYII=',
);

Sale _sale() => Sale.fromJson({
  'id': 1,
  'code': 'V-00001',
  'sale_type': 'cash',
  'total': 120,
  'paid_amount': 120,
  'balance': 0,
  'payment_status': 'pagada',
  'client': 'ANA ROJAS',
  'sale_date': '2026-09-17T10:00:00',
  'items': [
    {
      'name': 'ACEITE MOTUL 20W-50',
      'quantity': 2,
      'unit_price': 60,
      'discount': 0,
      'subtotal': 120,
    },
  ],
});

WorkOrder _order() => WorkOrder.fromJson({
  'id': 5,
  'code': 'OT-00005',
  'status': 'entregada',
  'status_label': 'Entregada',
  'payment_status': 'pagada',
  'total': 200,
  'balance': 50,
  'paid_amount': 150,
  'client': 'JUAN PAZ',
  'client_phone': '70011223',
  'vehicle': 'HONDA CG 150 · 1234-ABC',
  'mechanic': 'CARLOS ROJAS',
  'reception_date': '2026-09-17T09:30:00',
  'reported_issue': 'Ruido en frenos y pierde aceite',
  'diagnosis': 'Pastillas gastadas; retén de motor dañado',
  'mileage': 15230,
  'fuel_level': '1/2',
  'received_items': 'Casco, herramientas',
  'subtotal_services': 120,
  'subtotal_parts': 80,
  'services': [
    {
      'id': 70,
      'description': 'FRENOS',
      'price': 120,
      'quantity': 1,
      'subtotal': 120,
    },
  ],
  'parts': [
    {
      'id': 80,
      'name': 'PASTILLA DE FRENO',
      'quantity': 2,
      'unit_price': 40,
      'subtotal': 80,
    },
  ],
  'photos': [],
});

bool _isPdf(Uint8List b) =>
    b.length > 4 &&
    b[0] == 0x25 &&
    b[1] == 0x50 &&
    b[2] == 0x44 &&
    b[3] == 0x46;

void main() {
  letterTests();
  test(
    'Recibo de venta: con y sin logo genera un PDF válido y liviano',
    () async {
      final sin = await buildReceiptPdf(_sale(), company: 'TALLER DEMO');
      final con = await buildReceiptPdf(
        _sale(),
        company: 'TALLER DEMO',
        logo: _png,
      );
      expect(_isPdf(sin), isTrue);
      expect(_isPdf(con), isTrue);
      expect(con.length, greaterThan(sin.length));
      expect(con.length, lessThan(100 * 1024));
    },
  );

  test('Recibo de OT: con y sin logo genera un PDF válido y liviano', () async {
    final sin = await buildWorkOrderPdf(_order(), company: 'TALLER DEMO');
    final con = await buildWorkOrderPdf(
      _order(),
      company: 'TALLER DEMO',
      logo: _png,
    );
    expect(_isPdf(sin), isTrue);
    expect(_isPdf(con), isTrue);
    expect(con.length, greaterThan(sin.length));
    expect(con.length, lessThan(100 * 1024));
  });

  test('Logo vacío se ignora (no rompe el PDF)', () async {
    final b = await buildReceiptPdf(_sale(), logo: Uint8List(0));
    expect(_isPdf(b), isTrue);
  });
}

// ── Tamaño carta ──────────────────────────────────────────────────────
void letterTests() {
  final company = Company(
    id: 1,
    name: 'MOTO TALLER DEMO',
    phone: '700-12345',
    address: 'Av. Banzer 3er anillo, Santa Cruz',
    themePrimary: '#1D4ED8',
  );

  test('Carta: recibo de venta y OT generan PDF válido', () async {
    final v = await buildReceiptLetterPdf(
      _sale(),
      company: company,
      logo: _png,
    );
    final o = await buildWorkOrderLetterPdf(
      _order(),
      company: company,
      logo: _png,
    );
    expect(_isPdf(v), isTrue);
    expect(_isPdf(o), isTrue);
    expect(v.length, lessThan(150 * 1024));
    expect(o.length, lessThan(150 * 1024));
    // Sin empresa ni logo tampoco falla.
    expect(_isPdf(await buildReceiptLetterPdf(_sale())), isTrue);
    expect(_isPdf(await buildWorkOrderLetterPdf(_order())), isTrue);
    // Muestras para revisar el diseño (se ignoran en git).
    final out = Directory('build/pdf_samples')..createSync(recursive: true);
    File('${out.path}/venta-carta.pdf').writeAsBytesSync(v);
    File('${out.path}/ot-carta.pdf').writeAsBytesSync(o);
  });
}
