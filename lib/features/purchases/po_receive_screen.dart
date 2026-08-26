import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import 'purchases_repository.dart';

/// Detalle de una orden de compra y recepción de mercadería: por cada línea,
/// la cantidad a recibir (por defecto lo pendiente) + almacén. Al confirmar
/// suma stock, avanza la OC y genera la compra (cuenta por pagar).
class PoReceiveScreen extends ConsumerStatefulWidget {
  final int orderId;
  final String code;
  const PoReceiveScreen({super.key, required this.orderId, required this.code});

  @override
  ConsumerState<PoReceiveScreen> createState() => _PoReceiveScreenState();
}

class _PoReceiveScreenState extends ConsumerState<PoReceiveScreen> {
  PoDetail? _detail;
  bool _loading = true;
  bool _submitting = false;
  Object? _error;

  int? _warehouseId;
  final Map<int, TextEditingController> _qty = {}; // po_item_id -> qty
  final _invoiceCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    for (final c in _qty.values) {
      c.dispose();
    }
    _invoiceCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final d = await ref.read(purchasesRepositoryProvider).orderDetail(widget.orderId);
      if (!mounted) return;
      for (final it in d.items) {
        _qty[it.poItemId] = TextEditingController(
          text: it.pending > 0 ? qty(it.pending) : '',
        );
      }
      setState(() {
        _detail = d;
        _warehouseId = d.warehouses.isNotEmpty ? d.warehouses.first.id : null;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _receive() async {
    final d = _detail;
    if (d == null) return;
    if (_warehouseId == null) {
      _snack('No hay un almacén donde recibir.');
      return;
    }

    final items = <Map<String, dynamic>>[];
    for (final it in d.items) {
      final v = double.tryParse(
              (_qty[it.poItemId]?.text ?? '').replaceAll(',', '.')) ??
          0;
      if (v > 0) items.add({'po_item_id': it.poItemId, 'quantity': v});
    }
    if (items.isEmpty) {
      _snack('Ingresa la cantidad a recibir de al menos un producto.');
      return;
    }

    setState(() => _submitting = true);
    try {
      final msg = await ref.read(purchasesRepositoryProvider).receive(
            widget.orderId,
            warehouseId: _warehouseId!,
            items: items,
            invoiceNumber:
                _invoiceCtrl.text.trim().isEmpty ? null : _invoiceCtrl.text.trim(),
            notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context, true);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(msg)));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _snack(e.message);
      }
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    return Scaffold(
      appBar: AppBar(title: Text('Recibir ${widget.code}')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('$_error', textAlign: TextAlign.center),
                  ),
                )
              : _content(d!),
      bottomNavigationBar: (d != null)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                  icon: _submitting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white))
                      : const Icon(Icons.check),
                  label: const Text('Recibir y sumar al stock'),
                  onPressed: _submitting ? null : _receive,
                ),
              ),
            )
          : null,
    );
  }

  Widget _content(PoDetail d) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(d.supplier ?? 'Sin proveedor',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),

        // Almacén destino
        DropdownButtonFormField<int>(
          initialValue: _warehouseId,
          decoration: const InputDecoration(
              labelText: 'Almacén de destino', border: OutlineInputBorder()),
          items: [
            for (final w in d.warehouses)
              DropdownMenuItem(value: w.id, child: Text(w.name)),
          ],
          onChanged: (v) => setState(() => _warehouseId = v),
        ),
        const SizedBox(height: 16),

        const Text('Productos',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        for (final it in d.items) _itemRow(it),

        const SizedBox(height: 16),
        TextField(
          controller: _invoiceCtrl,
          decoration: const InputDecoration(
              labelText: 'N° de factura (opcional)',
              border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _notesCtrl,
          minLines: 1,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Notas (opcional)', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        const Text(
          'Se sumará al stock del almacén, avanzará la orden y se generará la '
          'compra (cuenta por pagar) por lo recibido.',
          style: TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _itemRow(PoItem it) {
    final done = it.pending <= 0;
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(it.product ?? '—',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(
                    'Pedido: ${qty(it.ordered)} · Recibido: ${qty(it.received)} · '
                    'Pendiente: ${qty(it.pending)} ${it.unit ?? ''}',
                    style: const TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 84,
              child: done
                  ? const Chip(
                      label: Text('Completo'),
                      visualDensity: VisualDensity.compact,
                    )
                  : TextField(
                      controller: _qty[it.poItemId],
                      keyboardType: const TextInputType.numberWithOptions(
                          decimal: true),
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(
                        labelText: 'Recibir',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
