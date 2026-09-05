import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import 'purchases_repository.dart';

/// Detalle de una compra directa (proveedor, ítems y totales).
class DirectPurchaseDetailScreen extends ConsumerStatefulWidget {
  final int purchaseId;
  final String code;
  const DirectPurchaseDetailScreen(
      {super.key, required this.purchaseId, required this.code});

  @override
  ConsumerState<DirectPurchaseDetailScreen> createState() =>
      _DirectPurchaseDetailScreenState();
}

class _DirectPurchaseDetailScreenState
    extends ConsumerState<DirectPurchaseDetailScreen> {
  DirectPurchaseDetail? _d;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ref
          .read(purchasesRepositoryProvider)
          .directPurchaseDetail(widget.purchaseId);
      if (mounted) setState(() { _d = d; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.code)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('$_error', textAlign: TextAlign.center),
                  ),
                )
              : _body(_d!),
    );
  }

  Widget _body(DirectPurchaseDetail d) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.brown.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Text('Compra directa',
                          style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Colors.brown)),
                    ),
                    const Spacer(),
                    Text(d.paymentLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 8),
                _line('Proveedor', d.supplier ?? '-'),
                _line('Fecha', d.date ?? '-'),
                if (d.invoiceNumber != null && d.invoiceNumber!.isNotEmpty)
                  _line('Factura', d.invoiceNumber!),
                if (d.notes != null && d.notes!.isNotEmpty)
                  _line('Notas', d.notes!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Productos',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        for (final it in d.items)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              title: Text(it.name ?? 'Producto'),
              subtitle: Text('${qty(it.quantity)} × ${money(it.unitCost)}'),
              trailing: Text(money(it.subtotal),
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _totalRow('Total', d.total, bold: true),
                _totalRow('Pagado', d.paidAmount),
                if (d.total - d.paidAmount > 0)
                  _totalRow('Saldo', d.total - d.paidAmount),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _line(String k, String v) => Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text('$k: $v', style: const TextStyle(color: Colors.black87)),
      );

  Widget _totalRow(String k, double v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.normal)),
            Text(money(v),
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.normal)),
          ],
        ),
      );
}
