import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../core/models.dart';

class ReceiptScreen extends StatelessWidget {
  final Sale sale;
  const ReceiptScreen({super.key, required this.sale});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Venta registrada'),
        automaticallyImplyLeading: false,
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
            icon: const Icon(Icons.point_of_sale),
            label: const Text('Nueva venta'),
            onPressed: () => Navigator.pop(context),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            style:
                OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            onPressed: () => Navigator.of(context)
                .popUntil((r) => r.isFirst),
            child: const Text('Volver al inicio'),
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
