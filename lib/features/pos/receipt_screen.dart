import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

class ReceiptScreen extends ConsumerWidget {
  final Sale sale;
  const ReceiptScreen({super.key, required this.sale});

  Future<void> _share(WidgetRef ref) async {
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
          IconButton(
            tooltip: 'Compartir recibo',
            icon: const Icon(Icons.share),
            onPressed: () => _share(ref),
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
                      child: Row(
                        children: [
                          Expanded(
                              child: Text(
                                  '${qty(it.quantity)} x ${it.name}')),
                          Text(money(it.subtotal)),
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
            icon: const Icon(Icons.share),
            label: const Text('Compartir recibo'),
            onPressed: () => _share(ref),
          ),
          const SizedBox(height: 8),
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
