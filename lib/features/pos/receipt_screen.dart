import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

class ReceiptScreen extends ConsumerWidget {
  final Sale sale;
  const ReceiptScreen({super.key, required this.sale});

  Future<void> _sharePdf(WidgetRef ref) async {
    final company = ref.read(authControllerProvider).me?.company?.name;
    final bytes = await buildReceiptPdf(sale, company: company);
    await Printing.sharePdf(bytes: bytes, filename: 'recibo-${sale.code}.pdf');
  }

  Future<void> _shareText(WidgetRef ref) async {
    final company = ref.read(authControllerProvider).me?.company?.name;
    await SharePlus.instance
        .share(ShareParams(text: buildReceiptText(sale, company: company)));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Venta registrada'),
        automaticallyImplyLeading: false,
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Compartir recibo',
            icon: const Icon(Icons.share),
            onSelected: (v) =>
                v == 'pdf' ? _sharePdf(ref) : _shareText(ref),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'pdf',
                child: ListTile(
                    leading: Icon(Icons.picture_as_pdf_outlined),
                    title: Text('Compartir PDF')),
              ),
              PopupMenuItem(
                value: 'text',
                child: ListTile(
                    leading: Icon(Icons.text_snippet_outlined),
                    title: Text('Compartir texto')),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Center(
            child: Column(
              children: [
                const CircleAvatar(
                  radius: 34,
                  backgroundColor: Color(0xFFE6F4EA),
                  child: Icon(Icons.check_circle,
                      color: Colors.green, size: 44),
                ),
                const SizedBox(height: 12),
                Text(sale.code,
                    style: const TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
                if (sale.client != null)
                  Text('Cliente: ${sale.client}',
                      style: const TextStyle(color: Colors.black54)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  for (final it in sale.items)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                  child: Text(
                                      '${qty(it.quantity)} x ${it.name}')),
                              Text(money(it.subtotal)),
                            ],
                          ),
                          if (it.discount > 0)
                            Text('   Desc. -${money(it.discount)}',
                                style: const TextStyle(
                                    color: Colors.red, fontSize: 11)),
                        ],
                      ),
                    ),
                  const Divider(),
                  _totalRow('Total', sale.total, bold: true),
                  _totalRow('Pagado', sale.paidAmount),
                  if (sale.balance > 0) _totalRow('Saldo', sale.balance),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.picture_as_pdf_outlined),
            label: const Text('Compartir recibo (PDF)'),
            onPressed: () => _sharePdf(ref),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            icon: const Icon(Icons.text_snippet_outlined),
            label: const Text('Compartir como texto'),
            onPressed: () => _shareText(ref),
          ),
          const SizedBox(height: 4),
          OutlinedButton(
            style:
                OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => Navigator.pop(context),
            child: const Text('Cerrar'),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, double value, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.normal)),
            Text(money(value),
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.normal)),
          ],
        ),
      );
}

/// Recibo en PDF (formato ticket 80 mm) para compartir/imprimir.
Future<Uint8List> buildReceiptPdf(Sale sale, {String? company}) async {
  final doc = pw.Document();
  final df = DateFormat('dd/MM/yyyy HH:mm');

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
          child: pw.Text('Recibo ${sale.code}',
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
        ),
        if (sale.saleDate != null)
          pw.Center(
            child: pw.Text(df.format(sale.saleDate!.toLocal()),
                style: const pw.TextStyle(fontSize: 9)),
          ),
        if (sale.client != null && sale.client!.isNotEmpty)
          pw.Padding(
            padding: const pw.EdgeInsets.only(top: 2),
            child: pw.Text('Cliente: ${sale.client}',
                style: const pw.TextStyle(fontSize: 9)),
          ),
        pw.Divider(height: 12),
        for (final it in sale.items) ...[
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Expanded(
                child: pw.Text('${qty(it.quantity)} x ${it.name}',
                    style: const pw.TextStyle(fontSize: 9)),
              ),
              pw.Text(money(it.subtotal),
                  style: const pw.TextStyle(fontSize: 9)),
            ],
          ),
          if (it.discount > 0)
            pw.Text('   Desc. -${money(it.discount)}',
                style: const pw.TextStyle(fontSize: 8, color: PdfColors.red)),
        ],
        pw.Divider(height: 12),
        totalRow('Total', money(sale.total), bold: true),
        totalRow('Pagado', money(sale.paidAmount)),
        if (sale.balance > 0) totalRow('Saldo', money(sale.balance)),
        pw.SizedBox(height: 10),
        pw.Center(
          child: pw.Text('¡Gracias por su compra!',
              style: const pw.TextStyle(fontSize: 9)),
        ),
      ],
    ),
  ));

  return doc.save();
}

/// Recibo en texto plano para compartir (WhatsApp, etc.).
String buildReceiptText(Sale sale, {String? company}) {
  const line = '--------------------------------';
  final b = StringBuffer();
  if (company != null && company.isNotEmpty) b.writeln(company);
  b.writeln('Recibo ${sale.code}');
  if (sale.saleDate != null) {
    b.writeln(DateFormat('dd/MM/yyyy HH:mm').format(sale.saleDate!.toLocal()));
  }
  if (sale.client != null && sale.client!.isNotEmpty) {
    b.writeln('Cliente: ${sale.client}');
  }
  b.writeln(line);
  for (final it in sale.items) {
    b.writeln('${qty(it.quantity)} x ${it.name}');
    if (it.discount > 0) b.writeln('    Desc. -${money(it.discount)}');
    b.writeln('    ${money(it.subtotal)}');
  }
  b.writeln(line);
  b.writeln('Total:  ${money(sale.total)}');
  b.writeln('Pagado: ${money(sale.paidAmount)}');
  if (sale.balance > 0) b.writeln('Saldo:  ${money(sale.balance)}');
  b.writeln(line);
  b.writeln('¡Gracias por su compra!');
  return b.toString();
}
