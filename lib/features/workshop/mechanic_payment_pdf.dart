import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/format.dart';
import 'mechanic_payments_repository.dart';

/// Comprobante de pago a mecánico en PDF (ticket 80 mm) para compartir.
Future<Uint8List> buildMechanicPaymentPdf(
  MechanicPaymentItem pago, {
  required String mechanicName,
  String? company,
}) async {
  final doc = pw.Document();

  String dateStr = '';
  if (pago.date != null) {
    final d = DateTime.tryParse(pago.date!);
    if (d != null) dateStr = DateFormat('dd/MM/yyyy').format(d.toLocal());
  }

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
          child: pw.Text('Comprobante de pago',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ),
        pw.Center(
          child: pw.Text('N.º ${pago.id}',
              style: const pw.TextStyle(fontSize: 9)),
        ),
        pw.Divider(height: 12),
        infoRow('Mecánico', mechanicName),
        if (dateStr.isNotEmpty) infoRow('Fecha', dateStr),
        infoRow('Método', (pago.method ?? 'efectivo')),
        infoRow('Origen', pago.sourceLabel),
        pw.Divider(height: 12),
        pw.Text('Órdenes de trabajo',
            style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold)),
        for (final o in pago.orders)
          pw.Row(children: [
            pw.Expanded(
                child: pw.Text('${o.code}   ${_fmt(o.date)}',
                    style: const pw.TextStyle(fontSize: 9))),
            pw.Text(money(o.commission), style: const pw.TextStyle(fontSize: 9)),
          ]),
        pw.Divider(height: 12),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          children: [
            pw.Text('Total pagado',
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
            pw.Text(money(pago.amount),
                style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
          ],
        ),
        if (pago.notes != null && pago.notes!.isNotEmpty) ...[
          pw.SizedBox(height: 6),
          pw.Text('Notas: ${pago.notes}',
              style: const pw.TextStyle(fontSize: 8)),
        ],
        pw.SizedBox(height: 28),
        pw.Container(
            decoration: const pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(width: .5)))),
        pw.SizedBox(height: 2),
        pw.Center(
          child: pw.Text('Recibí conforme — $mechanicName',
              style: const pw.TextStyle(fontSize: 8)),
        ),
      ],
    ),
  ));

  return doc.save();
}

String _fmt(String? iso) {
  if (iso == null) return '';
  final d = DateTime.tryParse(iso);
  if (d == null) return '';
  return DateFormat('dd/MM/yyyy').format(d.toLocal());
}
