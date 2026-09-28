import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/app_toast.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/module_colors.dart';
import '../../core/upper_case.dart';
import '../inventory/catalog_picker_field.dart';
import '../inventory/catalogs_repository.dart';
import '../inventory/moto_models_field.dart';
import '../pos/barcode_capture_screen.dart';
import '../pos/pos_repository.dart';

/// Alta de producto desde el móvil, tan completa como el formulario web:
/// foto, nombre, precios de venta y compra, código de referencia, código de
/// barras (con escáner), unidad, categoría, marca, modelos compatibles, stock
/// inicial y mínimo, y descripción. Agrupado por secciones para que se llene
/// de arriba abajo sin perderse. Devuelve el `Product` creado (para agregarlo
/// al carrito si se abrió desde el POS).
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
  final _code = TextEditingController();
  final _barcode = TextEditingController();
  final _stock = TextEditingController();
  final _minStock = TextEditingController();
  final _description = TextEditingController();

  String? _unit;
  int? _categoryId;
  int? _brandId;
  int? _warehouseId;
  List<CatalogItem> _models = [];

  final _picker = ImagePicker();
  XFile? _photo;

  ProductCatalogs? _catalogs;
  bool _loading = true;
  bool _saving = false;
  Object? _error;

  /// Tras el primer "Guardar" los errores se muestran en el propio campo.
  bool _tried = false;

  @override
  void initState() {
    super.initState();
    _load();
    // Repinta para el aviso "compra mayor que venta" mientras se escribe.
    _price.addListener(_refresh);
    _cost.addListener(_refresh);
  }

  void _refresh() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    for (final c in [
      _name,
      _price,
      _cost,
      _code,
      _barcode,
      _stock,
      _minStock,
      _description,
    ]) {
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
          _unit = c.defaultUnit;
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

  double? _num(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.'));

  String? _text(TextEditingController c) =>
      c.text.trim().isEmpty ? null : c.text.trim();

  String? get _nameError => _tried && _name.text.trim().isEmpty
      ? 'Escribe el nombre del producto'
      : null;

  String? get _priceError =>
      _tried && _num(_price) == null ? 'Indica el precio de venta' : null;

  Future<void> _save() async {
    setState(() => _tried = true);
    final name = _name.text.trim();
    final price = _num(_price);
    if (name.isEmpty || price == null) {
      AppToast.error(
        context,
        'Completa el nombre y el precio de venta.',
        title: 'Faltan datos',
      );
      return;
    }
    final stock = widget.hideInitialStock ? 0.0 : (_num(_stock) ?? 0);
    if (stock > 0 && _warehouseId == null) {
      AppToast.error(context, 'Selecciona un almacén para el stock inicial.');
      return;
    }

    setState(() => _saving = true);
    try {
      final product = await ref
          .read(posRepositoryProvider)
          .createProduct(
            name: name,
            price: price,
            cost: _num(_cost),
            unit: _unit,
            code: _text(_code),
            barcode: _text(_barcode),
            description: _text(_description),
            minStock: int.tryParse(_minStock.text.trim()),
            categoryId: _categoryId,
            brandId: _brandId,
            motoModelIds: [for (final m in _models) m.id],
            initialStock: stock > 0 ? stock : null,
            warehouseId: stock > 0 ? _warehouseId : null,
            photoPath: _photo?.path,
          );
      if (!mounted) return;
      AppToast.success(context, '«${product.name}» creado.');
      Navigator.pop(context, product);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.apiError(context, e);
      }
    }
  }

  Future<void> _scanBarcode() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const BarcodeCaptureScreen()),
    );
    if (code != null && mounted) setState(() => _barcode.text = code);
  }

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
            if (_photo != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Quitar foto',
                  style: TextStyle(color: Colors.red),
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _photo = null);
                },
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
      if (mounted) AppToast.error(context, 'No se pudo obtener la imagen.');
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

  @override
  Widget build(BuildContext context) {
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
          : _form(),
      bottomNavigationBar: _loading || _error != null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
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
                  label: const Text('Guardar producto'),
                  onPressed: _saving ? null : _save,
                ),
              ),
            ),
    );
  }

  Widget _form() {
    final cat = _catalogs!;
    final price = _num(_price);
    final cost = _num(_cost);
    final costAbovePrice = price != null && cost != null && cost > price;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // ── Foto + nombre ────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _photoBox(),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _name,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: upperCaseFormatters,
                minLines: 2,
                maxLines: 3,
                onChanged: (_) {
                  if (_tried) setState(() {});
                },
                decoration: InputDecoration(
                  labelText: 'Nombre del producto *',
                  hintText: 'Ej. ACEITE 20W50 4T',
                  errorText: _nameError,
                  border: const OutlineInputBorder(),
                  alignLabelWithHint: true,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // ── Precios ──────────────────────────────────────────────────
        _Section(
          icon: Icons.payments_outlined,
          color: ModuleColors.sales,
          title: 'Precios',
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _money(
                    _price,
                    'Precio de venta *',
                    helper: 'Lo que cobras',
                    error: _priceError,
                    onChanged: (_) {
                      if (_tried) setState(() {});
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _money(
                    _cost,
                    'Precio de compra',
                    helper: 'Lo que te costó',
                  ),
                ),
              ],
            ),
            if (costAbovePrice)
              const _Hint(
                icon: Icons.warning_amber_rounded,
                color: Colors.orange,
                text:
                    'El precio de compra es mayor que el de venta. '
                    '¿Los escribiste al revés?',
              ),
          ],
        ),

        // ── Identificación ───────────────────────────────────────────
        _Section(
          icon: Icons.qr_code_2,
          color: ModuleColors.products,
          title: 'Identificación',
          children: [
            _text2(
              _code,
              'Código de referencia',
              hint: 'Ej. 15400-KWB-601',
              helper: 'El del fabricante o el que usas en la tienda.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _barcode,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: upperCaseFormatters,
              decoration: InputDecoration(
                labelText: 'Código de barras',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  tooltip: 'Escanear',
                  icon: const Icon(Icons.qr_code_scanner),
                  onPressed: _scanBarcode,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _unitField(cat),
            const _Hint(
              icon: Icons.info_outline,
              color: Colors.black45,
              text: 'El SKU interno se genera solo al guardar.',
            ),
          ],
        ),

        // ── Clasificación ────────────────────────────────────────────
        _Section(
          icon: Icons.category_outlined,
          color: ModuleColors.brands,
          title: 'Clasificación',
          children: [
            CatalogPickerField(
              label: 'Categoría',
              type: CatalogType.categories,
              options: cat.categories,
              value: _categoryId,
              onChanged: (v) => setState(() => _categoryId = v?.id),
              onCreated: (o) => _addOption(categories: o),
            ),
            const SizedBox(height: 12),
            CatalogPickerField(
              label: 'Marca',
              type: CatalogType.brands,
              options: cat.brands,
              value: _brandId,
              onChanged: (v) => setState(() => _brandId = v?.id),
              onCreated: (o) => _addOption(brands: o),
            ),
            const SizedBox(height: 12),
            MotoModelsField(
              value: _models,
              onChanged: (v) => setState(() => _models = v),
            ),
          ],
        ),

        // ── Stock ────────────────────────────────────────────────────
        _Section(
          icon: Icons.inventory_2_outlined,
          color: Colors.amber.shade800,
          title: 'Stock',
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (!widget.hideInitialStock) ...[
                  Expanded(
                    child: _qty(
                      _stock,
                      'Stock inicial',
                      helper: 'Lo que tienes hoy',
                      decimal: true,
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: _qty(
                    _minStock,
                    'Stock mínimo',
                    helper: 'Aviso al llegar aquí',
                  ),
                ),
              ],
            ),
            if (!widget.hideInitialStock) _warehouseField(cat),
          ],
        ),

        // ── Descripción ──────────────────────────────────────────────
        _Section(
          icon: Icons.notes,
          color: Colors.blueGrey,
          title: 'Descripción',
          subtitle: 'Opcional',
          children: [
            TextField(
              controller: _description,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: upperCaseFormatters,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(
                hintText: 'Medidas, material, notas para el vendedor…',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _photoBox() {
    final photo = _photo;
    return GestureDetector(
      onTap: _pickPhoto,
      child: Container(
        width: 92,
        height: 92,
        decoration: BoxDecoration(
          color: ModuleColors.soft(ModuleColors.products),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: ModuleColors.products.withValues(alpha: .35),
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: photo == null
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.add_a_photo_outlined,
                    color: ModuleColors.onSoft(ModuleColors.products),
                    size: 28,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Foto',
                    style: TextStyle(
                      fontSize: 12,
                      color: ModuleColors.onSoft(ModuleColors.products),
                    ),
                  ),
                ],
              )
            : Image.file(File(photo.path), fit: BoxFit.cover, cacheWidth: 300),
      ),
    );
  }

  Widget _unitField(ProductCatalogs cat) {
    // Catálogo de unidades de la empresa (mismo que la web). Si la empresa
    // todavía no tiene, se escribe libre.
    final units = {cat.defaultUnit, ...cat.units}.toList();
    if (cat.units.isEmpty) {
      return TextFormField(
        initialValue: _unit,
        textCapitalization: TextCapitalization.characters,
        inputFormatters: upperCaseFormatters,
        onChanged: (v) => _unit = v.trim().isEmpty ? null : v.trim(),
        decoration: const InputDecoration(
          labelText: 'Unidad de medida',
          border: OutlineInputBorder(),
        ),
      );
    }
    return DropdownButtonFormField<String>(
      initialValue: units.contains(_unit) ? _unit : units.first,
      isExpanded: true,
      decoration: const InputDecoration(
        labelText: 'Unidad de medida',
        border: OutlineInputBorder(),
      ),
      items: [
        for (final u in units) DropdownMenuItem(value: u, child: Text(u)),
      ],
      onChanged: (v) => setState(() => _unit = v),
    );
  }

  Widget _warehouseField(ProductCatalogs cat) {
    if (cat.warehouses.isEmpty) return const SizedBox.shrink();
    // Una sola bodega: no hace falta elegir, solo se informa dónde queda.
    if (cat.warehouses.length == 1) {
      return _Hint(
        icon: Icons.warehouse_outlined,
        color: Colors.black45,
        text: 'El stock inicial se guarda en ${cat.warehouses.first.name}.',
      );
    }
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: DropdownButtonFormField<int>(
        initialValue: _warehouseId,
        isExpanded: true,
        decoration: const InputDecoration(
          labelText: 'Almacén del stock inicial',
          border: OutlineInputBorder(),
        ),
        items: [
          for (final w in cat.warehouses)
            DropdownMenuItem(value: w.id, child: Text(w.name)),
        ],
        onChanged: (v) => setState(() => _warehouseId = v),
      ),
    );
  }

  Widget _money(
    TextEditingController c,
    String label, {
    String? helper,
    String? error,
    ValueChanged<String>? onChanged,
  }) => TextField(
    controller: c,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    onChanged: onChanged,
    decoration: InputDecoration(
      labelText: label,
      prefixText: '$currencySymbol ',
      helperText: error == null ? helper : null,
      errorText: error,
      errorMaxLines: 2,
      border: const OutlineInputBorder(),
    ),
  );

  Widget _qty(
    TextEditingController c,
    String label, {
    String? helper,
    bool decimal = false,
  }) => TextField(
    controller: c,
    keyboardType: TextInputType.numberWithOptions(decimal: decimal),
    decoration: InputDecoration(
      labelText: label,
      helperText: helper,
      border: const OutlineInputBorder(),
    ),
  );

  Widget _text2(
    TextEditingController c,
    String label, {
    String? hint,
    String? helper,
  }) => TextField(
    controller: c,
    textCapitalization: TextCapitalization.characters,
    inputFormatters: upperCaseFormatters,
    decoration: InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      helperMaxLines: 2,
      border: const OutlineInputBorder(),
    ),
  );
}

/// Recuadro de sección: ícono en círculo suave del color del tema + título.
class _Section extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final List<Widget> children;

  const _Section({
    required this.icon,
    required this.color,
    required this.title,
    required this.children,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: ModuleColors.soft(color),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 17, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle!,
                  style: const TextStyle(fontSize: 12, color: Colors.black45),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

/// Aviso chico bajo un campo (información o advertencia).
class _Hint extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  const _Hint({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                color: color == Colors.black45 ? Colors.black54 : color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
