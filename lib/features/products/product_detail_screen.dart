import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../pos/pos_repository.dart';

/// Ficha de un producto: precio, stock (total y por almacén), origen, marca,
/// categoría y modelos compatibles. Si [showAdd] es true, ofrece "Agregar al
/// carrito" y devuelve el `Product` al hacer pop.
class ProductDetailScreen extends ConsumerStatefulWidget {
  final int productId;
  final String productName;
  final bool showAdd;

  const ProductDetailScreen({
    super.key,
    required this.productId,
    required this.productName,
    this.showAdd = false,
  });

  @override
  ConsumerState<ProductDetailScreen> createState() =>
      _ProductDetailScreenState();
}

class _ProductDetailScreenState extends ConsumerState<ProductDetailScreen> {
  ProductDetail? _detail;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ref.read(posRepositoryProvider).productDetail(widget.productId);
      if (mounted) setState(() { _detail = d; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _adjustDialog(ProductDetail d) async {
    WarehouseStock warehouse = d.stockByWarehouse.first;
    String type = 'in'; // in | out | set
    final qtyCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    const typeLabels = {'in': 'Entrada', 'out': 'Salida', 'set': 'Fijar a'};

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Ajustar stock'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: warehouse.id,
                  decoration: const InputDecoration(labelText: 'Almacén'),
                  items: [
                    for (final w in d.stockByWarehouse)
                      DropdownMenuItem(
                          value: w.id,
                          child: Text('${w.warehouse} (${qty(w.qty)})')),
                  ],
                  onChanged: (v) => setLocal(() => warehouse =
                      d.stockByWarehouse.firstWhere((w) => w.id == v)),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: 'Operación'),
                  items: [
                    for (final e in typeLabels.entries)
                      DropdownMenuItem(value: e.key, child: Text(e.value)),
                  ],
                  onChanged: (v) => setLocal(() => type = v ?? type),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: qtyCtrl,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      labelText: type == 'set' ? 'Cantidad final' : 'Cantidad'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Motivo (opcional)'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Aplicar')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final q = double.tryParse(qtyCtrl.text.replaceAll(',', '.')) ?? -1;
    if (q < 0 || (type != 'set' && q <= 0)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ingresa una cantidad válida.')));
      }
      return;
    }

    try {
      await ref.read(posRepositoryProvider).adjustStock(
            productId: d.id,
            warehouseId: warehouse.id,
            type: type,
            quantity: q,
            reason: reasonCtrl.text.trim().isEmpty ? null : reasonCtrl.text.trim(),
          );
      if (!mounted) return;
      setState(() => _loading = true);
      await _load(); // recarga la ficha con el stock actualizado
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Stock actualizado.')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final d = _detail;
    final canEdit = ref.watch(authControllerProvider).me?.can('products.edit') ?? false;
    return Scaffold(
      appBar: AppBar(
        title: Text(d?.name ?? widget.productName),
        actions: [
          if (d != null && canEdit && d.stockByWarehouse.isNotEmpty)
            IconButton(
              tooltip: 'Ajustar stock',
              icon: const Icon(Icons.tune),
              onPressed: () => _adjustDialog(d),
            ),
        ],
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
              : _content(d!),
      bottomNavigationBar: (d != null && widget.showAdd)
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50)),
                  icon: const Icon(Icons.add_shopping_cart),
                  label: Text(d.currentStock > 0
                      ? 'Agregar al carrito'
                      : 'Sin stock'),
                  onPressed: d.currentStock > 0
                      ? () => Navigator.pop(context, d.toProduct())
                      : null,
                ),
              ),
            )
          : null,
    );
  }

  Widget _content(ProductDetail d) {
    final low = d.currentStock <= 0;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(d.name,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text([d.sku, d.code, d.barcode].where((e) => e != null && e.isNotEmpty).join('  ·  '),
            style: const TextStyle(color: Colors.black54)),
        const SizedBox(height: 16),

        // Precio + stock total
        Row(
          children: [
            Expanded(
              child: _bigStat('Precio', money(d.price), Colors.blue),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _bigStat(
                'Stock total',
                '${qty(d.currentStock)} ${d.unit ?? ''}'.trim(),
                low ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // Atributos
        _chips([
          if (d.category != null && d.category!.isNotEmpty) ('Categoría', d.category!),
          if (d.brand != null && d.brand!.isNotEmpty) ('Marca', d.brand!),
          if (d.origin != null && d.origin!.isNotEmpty) ('Origen', d.origin!),
        ]),

        if (d.compatibleModels.isNotEmpty) ...[
          const SizedBox(height: 16),
          const Text('Modelos compatibles',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final m in d.compatibleModels)
                Chip(
                  label: Text(m),
                  visualDensity: VisualDensity.compact,
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
            ],
          ),
        ],

        const SizedBox(height: 16),
        const Text('Stock por almacén',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        if (d.stockByWarehouse.isEmpty)
          const Text('Sin almacenes registrados.',
              style: TextStyle(color: Colors.black54))
        else
          for (final w in d.stockByWarehouse)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.warehouse_outlined),
              title: Text(w.warehouse),
              trailing: Text('${qty(w.qty)} ${d.unit ?? ''}'.trim(),
                  style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: w.qty <= 0 ? Colors.red : null)),
            ),
      ],
    );
  }

  Widget _bigStat(String label, String value, Color color) => Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: .08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.black54, fontSize: 12)),
            const SizedBox(height: 4),
            Text(value,
                style: TextStyle(
                    fontSize: 18, fontWeight: FontWeight.w800, color: color)),
          ],
        ),
      );

  Widget _chips(List<(String, String)> items) => Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (label, value) in items)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.black12),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text.rich(TextSpan(children: [
                TextSpan(
                    text: '$label: ',
                    style: const TextStyle(color: Colors.black54)),
                TextSpan(
                    text: value,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              ])),
            ),
        ],
      );
}
