import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../pos/pos_repository.dart';

/// Alta rápida de producto desde el móvil. Devuelve el `Product` creado
/// (para agregarlo al carrito si se abrió desde el POS).
class NewProductScreen extends ConsumerStatefulWidget {
  /// Oculta el bloque de "Stock inicial" (p. ej. al crear el producto dentro
  /// de una compra: el stock lo suma la propia compra).
  final bool hideInitialStock;
  const NewProductScreen({super.key, this.hideInitialStock = false});

  @override
  ConsumerState<NewProductScreen> createState() => _NewProductScreenState();
}

class _NewProductScreenState extends ConsumerState<NewProductScreen> {
  final _name = TextEditingController();
  final _price = TextEditingController();
  final _cost = TextEditingController();
  final _barcode = TextEditingController();
  final _unit = TextEditingController(text: 'unidad');
  final _stock = TextEditingController();

  int? _categoryId;
  int? _brandId;
  int? _warehouseId;

  final _picker = ImagePicker();
  XFile? _photo;

  ProductCatalogs? _catalogs;
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
    for (final c in [_name, _price, _cost, _barcode, _unit, _stock]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await ref.read(posRepositoryProvider).productFormData();
      if (mounted) {
        setState(() {
          _catalogs = c;
          _warehouseId = c.warehouses.isNotEmpty ? c.warehouses.first.id : null;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.replaceAll(',', '.'));
    if (name.isEmpty || price == null) {
      _snack('Nombre y precio son obligatorios.');
      return;
    }
    final stock =
        widget.hideInitialStock ? 0.0 : (double.tryParse(_stock.text.replaceAll(',', '.')) ?? 0);
    if (stock > 0 && _warehouseId == null) {
      _snack('Selecciona un almacén para el stock inicial.');
      return;
    }

    setState(() => _saving = true);
    try {
      final product = await ref.read(posRepositoryProvider).createProduct(
            name: name,
            price: price,
            cost: double.tryParse(_cost.text.replaceAll(',', '.')),
            unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
            barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
            categoryId: _categoryId,
            brandId: _brandId,
            initialStock: stock > 0 ? stock : null,
            warehouseId: stock > 0 ? _warehouseId : null,
            photoPath: _photo?.path,
          );
      if (mounted) Navigator.pop(context, product);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(e.message);
      }
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  /// Elige la foto del producto: cámara o galería.
  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (!mounted || source == null) return;
    try {
      final picked = await _picker.pickImage(
        source: source,
        maxWidth: 1280,
        imageQuality: 80,
      );
      if (picked != null && mounted) setState(() => _photo = picked);
    } catch (_) {
      if (mounted) _snack('No se pudo obtener la imagen.');
    }
  }

  void _removePhoto() => setState(() => _photo = null);

  @override
  Widget build(BuildContext context) {
    final cat = _catalogs;
    return Scaffold(
      appBar: AppBar(title: const Text('Nuevo producto')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('$_error', textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _photoPicker(),
                    const SizedBox(height: 16),
                    _field(_name, 'Nombre *',
                        capitalize: true),
                    Row(children: [
                      Expanded(
                          child: _field(_price, 'Precio venta *',
                              number: true, prefix: '$currencySymbol ')),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _field(_cost, 'Costo',
                              number: true, prefix: '$currencySymbol ')),
                    ]),
                    _field(_barcode, 'Código de barras'),
                    _field(_unit, 'Unidad'),
                    if (cat != null && cat.categories.isNotEmpty)
                      _dropdown('Categoría', _categoryId, cat.categories,
                          (v) => setState(() => _categoryId = v)),
                    if (cat != null && cat.brands.isNotEmpty)
                      _dropdown('Marca', _brandId, cat.brands,
                          (v) => setState(() => _brandId = v)),
                    if (!widget.hideInitialStock) ...[
                      const Divider(height: 28),
                      const Text('Stock inicial (opcional)',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 8),
                      _field(_stock, 'Cantidad', number: true),
                      if (cat != null && cat.warehouses.isNotEmpty)
                        _dropdown('Almacén', _warehouseId, cat.warehouses,
                            (v) => setState(() => _warehouseId = v)),
                    ],
                    const SizedBox(height: 20),
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
                      label: const Text('Crear producto'),
                      onPressed: _saving ? null : _save,
                    ),
                  ],
                ),
    );
  }

  Widget _photoPicker() {
    final photo = _photo;
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: _pickPhoto,
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black26),
              ),
              clipBehavior: Clip.antiAlias,
              child: photo == null
                  ? const Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.add_a_photo_outlined,
                            color: Colors.black45, size: 30),
                        SizedBox(height: 6),
                        Text('Agregar foto',
                            style:
                                TextStyle(color: Colors.black54, fontSize: 12)),
                      ],
                    )
                  : Image.file(File(photo.path), fit: BoxFit.cover),
            ),
          ),
          if (photo != null)
            TextButton.icon(
              onPressed: _removePhoto,
              icon: const Icon(Icons.delete_outline, size: 18, color: Colors.red),
              label: const Text('Quitar foto',
                  style: TextStyle(color: Colors.red)),
            ),
        ],
      ),
    );
  }

  Widget _field(TextEditingController c, String label,
      {bool number = false, bool capitalize = false, String? prefix}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        keyboardType: number
            ? const TextInputType.numberWithOptions(decimal: true)
            : TextInputType.text,
        textCapitalization:
            capitalize ? TextCapitalization.words : TextCapitalization.none,
        decoration: InputDecoration(
            labelText: label, prefixText: prefix, border: const OutlineInputBorder()),
      ),
    );
  }

  Widget _dropdown(String label, int? value, List<IdName> items,
      ValueChanged<int?> onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<int>(
        initialValue: value,
        isExpanded: true,
        decoration:
            InputDecoration(labelText: label, border: const OutlineInputBorder()),
        items: [
          if (label == 'Categoría' || label == 'Marca')
            const DropdownMenuItem(value: null, child: Text('—')),
          for (final o in items)
            DropdownMenuItem(value: o.id, child: Text(o.name)),
        ],
        onChanged: onChanged,
      ),
    );
  }
}
