import 'dart:typed_data';

import 'package:intl/intl.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/pdf_letter.dart';

const _payLabels = {
  'pendiente': 'Pendiente',
  'parcial': 'Parcial',
  'pagada': 'Pagada',
};

const _typeLabels = {'cash': 'Contado', 'credit': 'Crédito'};

/// Recibo de venta en **tamaño carta** (para imprimir o enviar por correo):
/// cabecera con logo, datos del cliente, tabla de productos y totales.
Future<Uint8List> buildReceiptLetterPdf(
  Sale sale, {
  Company? company,
  Uint8List? logo,
}) async {
  final L = LetterDoc(company: company, logo: logo);
  final date = sale.saleDate != null
      ? DateFormat('dd/MM/yyyy HH:mm').format(sale.saleDate!.toLocal())
      : null;
  final payLabel = _payLabels[sale.paymentStatus] ?? sale.paymentStatus;
  final totalDiscount = sale.items.fold<double>(0, (s, it) => s + it.discount);
  final gross = sale.items.fold<double>(
    0,
    (s, it) => s + it.subtotal + it.discount,
  );

  final doc = L.document(
    (ctx) => [
      L.header(title: 'Recibo de venta', code: sale.code, date: date),
      L.cards([
        L.card('Cliente', [
          L.field('Nombre', sale.client ?? 'Consumidor final'),
        ]),
        L.card('Venta', [
          L.field('Tipo', _typeLabels[sale.saleType] ?? sale.saleType),
          L.field('Fecha', date),
        ]),
        L.card('Pago', [
          L.field('Estado', payLabel),
          L.field('Saldo', money(sale.balance)),
        ]),
      ]),
      L.sectionTitle('Detalle'),
      L.table(
        headers: const [
          '#',
          'Producto',
          'Cant.',
          'P. unit.',
          'Desc.',
          'Subtotal',
        ],
        widths: const [0.5, 5, 1, 1.5, 1.3, 1.6],
        numeric: const {2, 3, 4, 5},
        rows: [
          for (var i = 0; i < sale.items.length; i++)
            [
              '${i + 1}',
              sale.items[i].name,
              qty(sale.items[i].quantity),
              money(sale.items[i].unitPrice),
              sale.items[i].discount > 0
                  ? '-${money(sale.items[i].discount)}'
                  : '-',
              money(sale.items[i].subtotal),
            ],
        ],
      ),
      L.totals([
        if (totalDiscount > 0) TotalLine('Subtotal', money(gross)),
        if (totalDiscount > 0)
          TotalLine('Descuento', '-${money(totalDiscount)}'),
        TotalLine('TOTAL', money(sale.total), emphasis: true),
        TotalLine('Pagado', money(sale.paidAmount), success: true),
        if (sale.balance > 0)
          TotalLine('Saldo pendiente', money(sale.balance), danger: true),
      ]),
      L.thanks('¡Gracias por su compra!'),
    ],
  );
  return doc.save();
}
