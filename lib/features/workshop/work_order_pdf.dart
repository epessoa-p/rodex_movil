import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/format.dart';
import '../../core/models.dart';

const _payLabels = {
  'pendiente': 'Pendiente',
  'parcial': 'Parcial',
  'pagada': 'Pagada',
};

/// Recibo en PDF (formato ticket 80 mm) de una orden de trabajo del taller.
Future<Uint8List> buildWorkOrderPdf(WorkOrder o, {String? company}) async {
  final doc = pw.Document();

  String? dateStr;
  if (o.receptionDate != null) {
    final d = DateTime.tryParse(o.receptionDate!);
    if (d != null) dateStr = DateFormat('dd/MM/yyyy').format(d.toLocal());
  }

  pw.Widget totalRow(String k, String v, {bool bold = false}) => pw.Padding(
        padding: const pw.EdgeInsets.symmetric(vertical: 1),
        child: pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text(k,
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
            pw.Text(v,
                style: pw.TextStyle(
                    fontSize: 10,
                    fontWeight:
                        bold ? pw.FontWeight.bold : pw.FontWeight.normal)),
          ],
        ),
      );

  pw.Widget infoRow(String k, String v) => pw.Padding(
        padding: const pw.EdgeInsets.only(bottom: 1),
        child: pw.RichText(
          text: pw.TextSpan(
            style: const pw.TextStyle(fontSize: 9),
            children: [
              pw.TextSpan(
                  text: '$k: ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
              pw.TextSpan(text: v),
            ],
          ),
        ),
      );

  pw.Widget lineItem(String label, String amount) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Expanded(child: pw.Text(label, style: const pw.TextStyle(fontSize: 9))),
          pw.Text(amount, style: const pw.TextStyle(fontSize: 9)),
        ],
      );

  doc.addPage(pw.Page(
    pageFormat: PdfPageFormat.roll80,
    margin: const pw.EdgeInsets.all(12),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        if (company != null && company.isNotEmpty)
          pw.Center(
            child: pw.Text(company,
                style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold)),
          ),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text('Orden de Trabajo ${o.code}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ),
        if (dateStr != null)
          pw.Center(
            child: pw.Text(dateStr, style: const pw.TextStyle(fontSize: 9)),
          ),
        pw.Divider(height: 12),
        if (o.client != null) infoRow('Cliente', o.client!),
        if (o.vehicle != null) infoRow('Vehículo', o.vehicle!),
        if (o.mechanic != null) infoRow('Mecánico', o.mechanic!),
        if (o.diagnosis != null && o.diagnosis!.isNotEmpty)
          infoRow('Diagnóstico', o.diagnosis!),

        // Servicios
        if (o.services.isNotEmpty) ...[
          pw.Divider(height: 12),
          pw.Text('Servicios',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          for (final s in o.services)
            lineItem(
                '${s.description}${s.quantity > 1 ? ' x${s.quantity}' : ''}',
                money(s.subtotal)),
        ],

        // Repuestos
        if (o.parts.isNotEmpty) ...[
          pw.Divider(height: 12),
          pw.Text('Repuestos',
              style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
          for (final p in o.parts)
            lineItem('${p.name}${p.quantity > 1 ? ' x${p.quantity}' : ''}',
                money(p.subtotal)),
        ],

        pw.Divider(height: 12),
        if (o.subtotalServices > 0)
          totalRow('Servicios', money(o.subtotalServices)),
        if (o.subtotalParts > 0) totalRow('Repuestos', money(o.subtotalParts)),
        if (o.discount > 0) totalRow('Descuento', '-${money(o.discount)}'),
        totalRow('Total', money(o.total), bold: true),
        totalRow('Pagado', money(o.paidAmount)),
        if (o.balance > 0) totalRow('Saldo', money(o.balance)),
        pw.SizedBox(height: 4),
        pw.Center(
          child: pw.Text('Pago: ${_payLabels[o.paymentStatus] ?? o.paymentStatus}',
              style: const pw.TextStyle(fontSize: 9)),
        ),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text('¡Gracias por su preferencia!',
              style: const pw.TextStyle(fontSize: 9)),
        ),
      ],
    ),
  ));

  return doc.save();
}
