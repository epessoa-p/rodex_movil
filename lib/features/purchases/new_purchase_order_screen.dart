import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../products/products_screen.dart';
import 'purchases_repository.dart';

/// Línea de la OC en construcción.
class _PoLine {
  final int productId;
  final String name;
  double quantity;
  double unitCost;
  _PoLine(this.productId, this.name, this.quantity, this.unitCost);
  double get subtotal => quantity * unitCost;
}

/// Crear una orden de compra (proveedor + productos con cantidad y costo).
class NewPurchaseOrderScreen extends ConsumerStatefulWidget {
  const NewPurchaseOrderScreen({super.key});

  @override
  ConsumerState<NewPurchaseOrderScreen> createState() =>
      _NewPurchaseOrderScreenState();
}

class _NewPurchaseOrderScreenState
    extends ConsumerState<NewPurchaseOrderScreen> {
  List<Supplier> _suppliers = [];
  int? _supplierId;
  final _notes = TextEditingController();
  final List<_PoLine> _lines = [];
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final s = await ref.read(purchasesRepositoryProvider).suppliers();
      if (mounted) {
        setState(() {
          _suppliers = s;
          _supplierId = s.isNotEmpty ? s.first.id : null;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _addItem() async {
    Product? picked;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductsScreen(
        requireStock: false, // en una OC se piden productos aunque no haya stock
        onPick: (p) {
          picked = p;
          Navigator.of(context).pop();
        },
      ),
    ));
    if (picked == null || !mounted) return;

    final qtyCtrl = TextEditingController(text: '1');
    final costCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(picked!.name, maxLines: 2, overflow: TextOverflow.ellipsis),
        content: Row(
          children: [
            Expanded(
              child: TextField(
                controller: qtyCtrl,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(),
                decoration: const InputDecoration(labelText: 'Cantidad'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: costCtrl,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: 'Costo', prefixText: '$currencySymbol '),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Agregar')),
        ],
      ),
    );
    if (ok != true) return;
    final q = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
    final c = double.tryParse(costCtrl.text.replaceAll(',', '.')) ?? 0;
    if (q <= 0) {
      _snack('Cantidad inválida.');
      return;
    }
    setState(() => _lines.add(_PoLine(picked!.id, picked!.name, q, c)));
  }

  double get _total => _lines.fold(0, (s, l) => s + l.subtotal);

  Future<void> _save() async {
    if (_supplierId == null) {
      _snack('Elige un proveedor.');
      return;
    }
    if (_lines.isEmpty) {
      _snack('Agrega al menos un producto.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(purchasesRepositoryProvider).createPurchaseOrder(
            supplierId: _supplierId!,
            items: [
              for (final l in _lines)
                {
                  'product_id': l.productId,
                  'quantity': l.quantity.toInt(),
                  'unit_cost': l.unitCost,
                }
            ],
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(e.message);
      }
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva orden de compra')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('$_error', textAlign: TextAlign.center),
                  ),
                )
              : _suppliers.isEmpty
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: Text(
                            'No hay proveedores. Crea uno primero en Proveedores.',
                            textAlign: TextAlign.center),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        DropdownButtonFormField<int>(
                          initialValue: _supplierId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                              labelText: 'Proveedor',
                              border: OutlineInputBorder()),
                          items: [
                            for (final s in _suppliers)
                              DropdownMenuItem(
                                  value: s.id, child: Text(s.name)),
                          ],
                          onChanged: (v) => setState(() => _supplierId = v),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Productos',
                                style: TextStyle(fontWeight: FontWeight.w700)),
                            TextButton.icon(
                              onPressed: _addItem,
                              icon: const Icon(Icons.add),
                              label: const Text('Agregar'),
                            ),
                          ],
                        ),
                        if (_lines.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            child: Text('Sin productos.',
                                style: TextStyle(color: Colors.black54)),
                          )
                        else
                          for (int i = 0; i < _lines.length; i++)
                            Card(
                              child: ListTile(
                                dense: true,
                                title: Text(_lines[i].name),
                                subtitle: Text(
                                    '${qty(_lines[i].quantity)} x ${money(_lines[i].unitCost)}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(money(_lines[i].subtotal),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    IconButton(
                                      icon: const Icon(Icons.close,
                                          color: Colors.red),
                                      onPressed: () =>
                                          setState(() => _lines.removeAt(i)),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _notes,
                          minLines: 1,
                          maxLines: 3,
                          decoration: const InputDecoration(
                              labelText: 'Notas (opcional)',
                              border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text('Total',
                                style: TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w700)),
                            Text(money(_total),
                                style: const TextStyle(
                                    fontSize: 20, fontWeight: FontWeight.w800)),
                          ],
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          style: FilledButton.styleFrom(
                              minimumSize: const Size.fromHeight(50)),
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: Colors.white))
                              : const Icon(Icons.check),
                          label: const Text('Crear orden'),
                          onPressed: _saving ? null : _save,
                        ),
                      ],
                    ),
    );
  }
}
