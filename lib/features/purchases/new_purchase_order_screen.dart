import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/app_toast.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/upper_case.dart';
import '../products/products_screen.dart';
import 'purchase_discount_field.dart';
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
/// Con [editing] edita esa OC (solo borrador o enviada, como en la web).
class NewPurchaseOrderScreen extends ConsumerStatefulWidget {
  final PoDetail? editing;
  const NewPurchaseOrderScreen({super.key, this.editing});

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
  // 'sent' = lista para recibir; 'draft' = borrador (aún no se recibe).
  String _status = 'sent';
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
      final e = widget.editing;
      // El proveedor de la OC puede no estar en la lista (p. ej. inactivo):
      // se agrega para que el desplegable no falle.
      if (e?.supplierId != null && !s.any((x) => x.id == e!.supplierId)) {
        s.insert(
          0,
          Supplier(id: e!.supplierId!, name: e.supplier ?? 'Proveedor'),
        );
      }
      if (mounted) {
        setState(() {
          _suppliers = s;
          _supplierId = e?.supplierId ?? (s.isNotEmpty ? s.first.id : null);
          if (e != null) {
            _status = e.status == 'draft' ? 'draft' : 'sent';
            _notes.text = e.notes ?? '';
            _discountInput = e.discount > 0
                ? SupplierDiscount.amount(e.discount)
                : const SupplierDiscount.none();
            _lines
              ..clear()
              ..addAll([
                for (final it in e.items)
                  if (it.productId != null)
                    _PoLine(
                      it.productId!,
                      it.product ?? 'Producto',
                      it.ordered,
                      it.unitCost,
                    ),
              ]);
          }
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _addItem() async {
    Product? picked;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductsScreen(
          requireStock:
              false, // en una OC se piden productos aunque no haya stock
          hideInitialStock: true, // el stock lo suma la compra, no el alta
          onPick: (p) {
            picked = p;
            Navigator.of(context).pop();
          },
        ),
      ),
    );
    if (picked == null || !mounted) return;
    final r = await _askQtyCost(picked!.name);
    if (r == null) return;
    setState(() => _lines.add(_PoLine(picked!.id, picked!.name, r.$1, r.$2)));
  }

  /// Tocar una línea: cambiar cantidad y costo.
  Future<void> _editLine(int i) async {
    final l = _lines[i];
    final r = await _askQtyCost(l.name, quantity: l.quantity, cost: l.unitCost);
    if (r == null) return;
    setState(() {
      l.quantity = r.$1;
      l.unitCost = r.$2;
    });
  }

  /// Diálogo de cantidad + costo. Devuelve null si se cancela o es inválido.
  Future<(double, double)?> _askQtyCost(
    String name, {
    double? quantity,
    double? cost,
  }) async {
    final qtyCtrl = TextEditingController(
      text: quantity == null ? '1' : qty(quantity),
    );
    final costCtrl = TextEditingController(
      text: cost == null || cost == 0 ? '' : cost.toStringAsFixed(2),
    );
    final editing = quantity != null;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
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
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'Costo',
                  prefixText: '$currencySymbol ',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(editing ? 'Guardar' : 'Agregar'),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    final q = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? 0;
    final c = double.tryParse(costCtrl.text.replaceAll(',', '.')) ?? 0;
    if (q <= 0) {
      _snack('Cantidad inválida.');
      return null;
    }
    return (q, c);
  }

  double get _subtotal => _lines.fold(0, (s, l) => s + l.subtotal);

  /// Descuento del proveedor como lo escribió el usuario (% o monto).
  SupplierDiscount _discountInput = const SupplierDiscount.none();
  double get _discount => _discountInput.amountFor(_subtotal);

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
      final repo = ref.read(purchasesRepositoryProvider);
      final items = [
        for (final l in _lines)
          {
            'product_id': l.productId,
            'quantity': l.quantity.toInt(),
            'unit_cost': l.unitCost,
          },
      ];
      final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
      final e = widget.editing;
      if (e != null) {
        await repo.updatePurchaseOrder(
          e.id,
          supplierId: _supplierId!,
          items: items,
          status: _status,
          expectedDate: e.expectedDate,
          discount: _discount,
          notes: notes,
        );
      } else {
        await repo.createPurchaseOrder(
          supplierId: _supplierId!,
          items: items,
          status: _status,
          discount: _discount,
          notes: notes,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.apiError(context, e);
      }
    }
  }

  // Validaciones y errores locales: toast rojo arriba (visible sobre hojas).
  void _snack(String m) => AppToast.error(context, m);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.editing == null
              ? 'Nueva orden de compra'
              : 'Editar ${widget.editing!.code}',
        ),
      ),
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
                  textAlign: TextAlign.center,
                ),
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
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final s in _suppliers)
                      DropdownMenuItem(value: s.id, child: Text(s.name)),
                  ],
                  onChanged: (v) => setState(() => _supplierId = v),
                ),
                const SizedBox(height: 12),
                // Borrador: se arma con calma; Enviada: lista para recibir.
                SegmentedButton<String>(
                  showSelectedIcon: false,
                  segments: const [
                    ButtonSegment(
                      value: 'draft',
                      icon: Icon(Icons.edit_note, size: 18),
                      label: Text('Borrador'),
                    ),
                    ButtonSegment(
                      value: 'sent',
                      icon: Icon(Icons.send_outlined, size: 18),
                      label: Text('Enviada'),
                    ),
                  ],
                  selected: {_status},
                  onSelectionChanged: (s) => setState(() => _status = s.first),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 4, left: 2),
                  child: Text(
                    _status == 'draft'
                        ? 'Borrador: todavía no se puede recibir.'
                        : 'Enviada: lista para recibir la mercadería.',
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Productos',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
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
                    child: Text(
                      'Sin productos.',
                      style: TextStyle(color: Colors.black54),
                    ),
                  )
                else
                  for (int i = 0; i < _lines.length; i++)
                    Card(
                      child: ListTile(
                        dense: true,
                        onTap: () => _editLine(i),
                        title: Text(_lines[i].name),
                        subtitle: Text(
                          '${qty(_lines[i].quantity)} x ${money(_lines[i].unitCost)}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              money(_lines[i].subtotal),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.red),
                              onPressed: () =>
                                  setState(() => _lines.removeAt(i)),
                            ),
                          ],
                        ),
                      ),
                    ),
                const SizedBox(height: 12),
                TextField(
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: upperCaseFormatters,
                  controller: _notes,
                  minLines: 1,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Notas (opcional)',
                    border: OutlineInputBorder(),
                  ),
                ),

                const SizedBox(height: 16),
                // Descuento del proveedor: % / monto / total editable.
                PurchaseDiscountField(
                  subtotal: _subtotal,
                  value: _discountInput,
                  onChanged: (d) => setState(() => _discountInput = d),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(50),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.check),
                  label: Text(
                    widget.editing == null ? 'Crear orden' : 'Guardar cambios',
                  ),
                  onPressed: _saving ? null : _save,
                ),
              ],
            ),
    );
  }
}
