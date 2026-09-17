import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/app_toast.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/upper_case.dart';
import '../pos/pos_repository.dart';

/// Hoja de edición del producto: datos básicos y comerciales (nombre, precio,
/// costo, unidad, código de barras, categoría, marca, stock mínimo,
/// descripción, activo). El stock NO se edita aquí: va por "Ajustar stock"
/// (con kardex). Devuelve la ficha actualizada al guardar.
class ProductEditSheet extends ConsumerStatefulWidget {
  final ProductDetail product;
  const ProductEditSheet({super.key, required this.product});

  @override
  ConsumerState<ProductEditSheet> createState() => _ProductEditSheetState();
}

class _ProductEditSheetState extends ConsumerState<ProductEditSheet> {
  late final _name = TextEditingController(text: widget.product.name);
  late final _price = TextEditingController(
    text: widget.product.price.toStringAsFixed(2),
  );
  late final _cost = TextEditingController(
    text: widget.product.cost > 0 ? widget.product.cost.toStringAsFixed(2) : '',
  );
  late final _unit = TextEditingController(text: widget.product.unit ?? '');
  late final _barcode = TextEditingController(
    text: widget.product.barcode ?? '',
  );
  late final _minStock = TextEditingController(
    text: widget.product.minStock > 0 ? '${widget.product.minStock}' : '',
  );
  late final _description = TextEditingController(
    text: widget.product.description ?? '',
  );
  late int? _categoryId = widget.product.categoryId;
  late int? _brandId = widget.product.brandId;
  late bool _active = widget.product.active;

  ProductCatalogs? _catalogs;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
  }

  Future<void> _loadCatalogs() async {
    try {
      final c = await ref.read(posRepositoryProvider).productFormData();
      if (mounted) setState(() => _catalogs = c);
    } on ApiException {
      // sin catálogos: se edita el resto igual
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _price,
      _cost,
      _unit,
      _barcode,
      _minStock,
      _description,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    final price = _num(_price);
    if (_name.text.trim().isEmpty) {
      AppToast.error(
        context,
        'El nombre es obligatorio.',
        title: 'Falta el nombre',
      );
      return;
    }
    if (price == null || price < 0) {
      AppToast.error(
        context,
        'Ingresa un precio válido.',
        title: 'Precio inválido',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      String? nz(TextEditingController c) =>
          c.text.trim().isEmpty ? null : c.text.trim();
      final updated = await ref
          .read(posRepositoryProvider)
          .updateProduct(
            widget.product.id,
            name: _name.text.trim(),
            price: price,
            cost: _num(_cost),
            unit: nz(_unit),
            barcode: nz(_barcode),
            description: nz(_description),
            minStock: int.tryParse(_minStock.text.trim()),
            categoryId: _categoryId,
            brandId: _brandId,
            active: _active,
          );
      if (!mounted) return;
      AppToast.success(context, 'Producto actualizado.');
      Navigator.pop(context, updated);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.apiError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    InputDecoration dec(String label, {String? prefix}) => InputDecoration(
      labelText: label,
      prefixText: prefix,
      border: const OutlineInputBorder(),
    );
    final cats = _catalogs;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Editar producto',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                  ),
                ),
                if (widget.product.sku != null)
                  Text(
                    widget.product.sku!,
                    style: const TextStyle(fontSize: 12, color: Colors.black45),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: upperCaseFormatters,
              decoration: dec('Nombre *'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: dec('Precio *', prefix: '$currencySymbol '),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _cost,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: dec('Costo', prefix: '$currencySymbol '),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _barcode,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: upperCaseFormatters,
                    decoration: dec('Código de barras'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _unit,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: upperCaseFormatters,
                    decoration: dec('Unidad'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (cats != null) ...[
              DropdownButtonFormField<int?>(
                initialValue: _categoryId,
                isExpanded: true,
                decoration: dec('Categoría'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('—')),
                  for (final o in cats.categories)
                    DropdownMenuItem(value: o.id, child: Text(o.name)),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int?>(
                initialValue: _brandId,
                isExpanded: true,
                decoration: dec('Marca'),
                items: [
                  const DropdownMenuItem(value: null, child: Text('—')),
                  for (final o in cats.brands)
                    DropdownMenuItem(value: o.id, child: Text(o.name)),
                ],
                onChanged: (v) => setState(() => _brandId = v),
              ),
              const SizedBox(height: 10),
            ],
            TextField(
              controller: _minStock,
              keyboardType: TextInputType.number,
              decoration: dec('Stock mínimo (alerta)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _description,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: upperCaseFormatters,
              minLines: 2,
              maxLines: 4,
              decoration: dec('Descripción'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activo'),
              subtitle: const Text(
                'Inactivo: no aparece en ventas ni en el listado.',
                style: TextStyle(fontSize: 12),
              ),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const Padding(
              padding: EdgeInsets.only(bottom: 8),
              child: Text(
                'El stock se modifica con "Ajustar stock" (queda en el kardex).',
                style: TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
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
              label: const Text('Guardar'),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
