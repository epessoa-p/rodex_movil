import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/app_toast.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/upper_case.dart';
import '../inventory/catalog_picker_field.dart';
import '../inventory/catalogs_repository.dart';
import '../inventory/moto_models_field.dart';
import '../pos/barcode_capture_screen.dart';
import '../pos/pos_repository.dart';
import 'product_photo.dart';

/// Hoja de edición del producto: los mismos datos que el alta (nombre,
/// precios de venta y compra, código de referencia, código de barras, unidad,
/// categoría, marca, modelos compatibles, stock mínimo, descripción, activo). El stock NO se edita aquí: va por "Ajustar stock"
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
  late final _code = TextEditingController(text: widget.product.code ?? '');

  /// Unidad elegida del catálogo (si la empresa tiene unidades cargadas).
  late String? _unitChoice = widget.product.unit;

  late List<CatalogItem> _models = [
    for (final m in widget.product.motoModels)
      CatalogItem(
        id: m.id,
        name: m.name,
        brand: m.brand,
        engineCc: m.engineCc,
        year: m.year,
      ),
  ];
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

  late String? _imageUrl = widget.product.imageUrl;
  ProductCatalogs? _catalogs;
  bool _saving = false;
  bool _photoBusy = false;

  @override
  void initState() {
    super.initState();
    _loadCatalogs();
    // Repinta para el aviso "compra mayor que venta".
    _price.addListener(_refresh);
    _cost.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeCaptureScreen()),
    );
    if (code != null && mounted) setState(() => _barcode.text = code);
  }

  Future<void> _loadCatalogs() async {
    try {
      final c = await ref.read(posRepositoryProvider).productFormData();
      if (mounted) {
        setState(() {
          _catalogs = c;
          if (_unitChoice == null || _unitChoice!.trim().isEmpty) {
            _unitChoice = c.defaultUnit;
          }
        });
      }
    } on ApiException {
      // sin catálogos: se edita el resto igual
    }
  }

  /// Agrega al catálogo local la opción recién creada desde el selector.
  void _addOption({IdName? categories, IdName? brands}) {
    final c = _catalogs;
    if (c == null) return;
    setState(() {
      _catalogs = c.copyWith(
        categories:
            categories != null &&
                !c.categories.any((o) => o.id == categories.id)
            ? [...c.categories, categories]
            : null,
        brands: brands != null && !c.brands.any((o) => o.id == brands.id)
            ? [...c.brands, brands]
            : null,
      );
    });
  }

  /// Cambia la foto del producto. Se sube al momento (no espera al "Guardar")
  /// para que también sirva como atajo desde el listado.
  Future<void> _changePhoto() async {
    if (_photoBusy) return;
    final updated = await pickAndUpdateProductPhoto(
      context,
      ref,
      productId: widget.product.id,
      productName: widget.product.name,
      hasPhoto: _imageUrl != null,
      onUploadStart: () {
        if (mounted) setState(() => _photoBusy = true);
      },
    );
    if (!mounted) return;
    setState(() {
      _photoBusy = false;
      if (updated != null) _imageUrl = updated.imageUrl;
    });
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _price,
      _cost,
      _unit,
      _barcode,
      _code,
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
            unit: (_catalogs?.units.isNotEmpty ?? false)
                ? _unitChoice
                : nz(_unit),
            code: nz(_code),
            barcode: nz(_barcode),
            motoModelIds: [for (final m in _models) m.id],
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

  bool get _costAbovePrice {
    final price = _num(_price);
    final cost = _num(_cost);
    return price != null && cost != null && cost > price;
  }

  /// Unidad: del catálogo de la empresa (como en la web). Conserva la unidad
  /// actual aunque ya no esté en el catálogo (dato viejo), para no cambiarla
  /// sin querer. Sin catálogo, texto libre.
  Widget _unitField(
    ProductCatalogs? cats,
    InputDecoration Function(String, {String? prefix}) dec,
  ) {
    final units = cats?.units ?? const <String>[];
    if (units.isEmpty) {
      return TextField(
        controller: _unit,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: upperCaseFormatters,
        decoration: dec('Unidad de medida'),
      );
    }
    final current = _unitChoice;
    final options = {
      if (current != null && current.isNotEmpty) current,
      ...units,
    }.toList();
    return DropdownButtonFormField<String>(
      initialValue: options.contains(current) ? current : options.first,
      isExpanded: true,
      decoration: dec('Unidad de medida'),
      items: [
        for (final u in options) DropdownMenuItem(value: u, child: Text(u)),
      ],
      onChanged: (v) => setState(() => _unitChoice = v),
    );
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
            Row(
              children: [
                InkWell(
                  onTap: _photoBusy ? null : _changePhoto,
                  borderRadius: BorderRadius.circular(16),
                  child: ProductThumb(
                    imageUrl: _imageUrl,
                    size: 64,
                    showBadge: true,
                    busy: _photoBusy,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _photoBusy ? null : _changePhoto,
                        icon: const Icon(Icons.photo_camera_outlined, size: 18),
                        label: Text(
                          _imageUrl == null ? 'Agregar foto' : 'Cambiar foto',
                        ),
                      ),
                      const Padding(
                        padding: EdgeInsets.only(left: 8),
                        child: Text(
                          'La foto se guarda al elegirla.',
                          style: TextStyle(fontSize: 11, color: Colors.black54),
                        ),
                      ),
                    ],
                  ),
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
                    decoration: dec(
                      'Precio de venta *',
                      prefix: '$currencySymbol ',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _cost,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: dec(
                      'Precio de compra',
                      prefix: '$currencySymbol ',
                    ),
                  ),
                ),
              ],
            ),
            if (_costAbovePrice)
              const Padding(
                padding: EdgeInsets.only(top: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 16,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'El precio de compra es mayor que el de venta. '
                        '¿Los escribiste al revés?',
                        style: TextStyle(fontSize: 12, color: Colors.orange),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            TextField(
              controller: _code,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: upperCaseFormatters,
              decoration: dec('Código de referencia'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _barcode,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: upperCaseFormatters,
              decoration: dec('Código de barras').copyWith(
                suffixIcon: IconButton(
                  tooltip: 'Escanear',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scanBarcode,
                ),
              ),
            ),
            const SizedBox(height: 10),
            _unitField(cats, dec),
            const SizedBox(height: 10),
            // Categoría / Marca: buscar escribiendo; si no existe, se crea.
            if (cats != null) ...[
              CatalogPickerField(
                label: 'Categoría',
                type: CatalogType.categories,
                options: cats.categories,
                value: _categoryId,
                onChanged: (v) => setState(() => _categoryId = v?.id),
                onCreated: (o) => _addOption(categories: o),
              ),
              const SizedBox(height: 10),
              CatalogPickerField(
                label: 'Marca',
                type: CatalogType.brands,
                options: cats.brands,
                value: _brandId,
                onChanged: (v) => setState(() => _brandId = v?.id),
                onCreated: (o) => _addOption(brands: o),
              ),
              const SizedBox(height: 10),
            ],
            MotoModelsField(
              value: _models,
              onChanged: (v) => setState(() => _models = v),
            ),
            const SizedBox(height: 10),
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
