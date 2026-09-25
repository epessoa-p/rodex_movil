import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_toast.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/module_colors.dart';
import '../pos/pos_repository.dart';
import 'new_product_screen.dart';
import 'product_detail_screen.dart';
import 'product_photo.dart';

/// Buscador de productos reutilizable. Si [onPick] está definido, al tocar un
/// producto lo devuelve (para el POS); si no, es solo consulta.
class ProductsScreen extends ConsumerStatefulWidget {
  final void Function(Product)? onPick;
  // Exige stock > 0 para elegir (POS). En false permite elegir sin stock
  // (p. ej. al crear una orden de compra).
  final bool requireStock;

  /// Oculta el "Stock inicial" en el alta de producto (flujos de compra).
  final bool hideInitialStock;

  /// Tab del hub "Inventario": sin AppBar propio.
  final bool embedded;

  const ProductsScreen({
    super.key,
    this.onPick,
    this.requireStock = true,
    this.hideInitialStock = false,
    this.embedded = false,
  });

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _search = TextEditingController();
  final _scroll = ScrollController();
  List<Product> _items = [];
  bool _loading = true;
  int _page = 1;
  int _lastPage = 1;
  int _total = 0;
  String _q = '';
  String? _error;
  Timer? _debounce;

  /// Producto cuya foto se está subiendo (para el spinner de esa fila).
  int? _photoBusyId;

  @override
  void initState() {
    super.initState();
    // Paginado de 30 por página con paginador al pie (anterior / siguiente).
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  /// Búsqueda al dejar de escribir (o con Enter).
  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted && v.trim() != _q) _load(v);
    });
  }

  /// Va a la página [page] (reemplaza la lista y vuelve arriba).
  Future<void> _goTo(int page) => _load(_q, page: page);

  /// Selección directa desde la lista (POS/compra): agrega el producto sin abrir
  /// la ficha. Respeta el requisito de stock del modo actual.
  void _pick(Product p) {
    if (widget.requireStock && p.currentStock <= 0) {
      AppToast.error(context, '${p.name}: sin stock disponible.');
      return;
    }
    widget.onPick!(p);
  }

  /// Abre la ficha del producto (stock por almacén, ajustar, atributos). En modo
  /// "picking" la ficha también ofrece "Agregar" y devuelve el Product al POS.
  Future<void> _openDetail(Product p) async {
    final picking = widget.onPick != null;
    final picked = await Navigator.of(context).push<Product>(
      MaterialPageRoute(
        builder: (_) => ProductDetailScreen(
          productId: p.id,
          productName: p.name,
          showAdd: picking,
          requireStock: widget.requireStock,
        ),
      ),
    );
    if (picked != null && widget.onPick != null) widget.onPick!(picked);
  }

  /// Alta rápida de producto. Si se abrió desde el POS, el producto creado se
  /// agrega al carrito; si es consulta, refresca la lista.
  Future<void> _newProduct() async {
    final product = await Navigator.of(context).push<Product>(
      MaterialPageRoute(
        builder: (_) =>
            NewProductScreen(hideInitialStock: widget.hideInitialStock),
      ),
    );
    if (product == null) return;
    if (widget.onPick != null) {
      widget.onPick!(product);
    } else {
      _load(_search.text);
    }
  }

  /// Atajo del listado: tocar la miniatura cambia la foto sin abrir el
  /// formulario (cámara, galería o quitar). Al volver se refresca solo esa fila.
  Future<void> _changePhoto(Product p) async {
    if (_photoBusyId != null) return;
    final updated = await pickAndUpdateProductPhoto(
      context,
      ref,
      productId: p.id,
      productName: p.name,
      hasPhoto: p.imageUrl != null,
      onUploadStart: () {
        if (mounted) setState(() => _photoBusyId = p.id);
      },
    );
    if (!mounted) return;
    setState(() {
      _photoBusyId = null;
      if (updated != null) {
        final i = _items.indexWhere((e) => e.id == p.id);
        if (i >= 0) _items[i] = updated.toProduct();
      }
    });
  }

  Future<void> _load(String q, {int page = 1}) async {
    _debounce?.cancel();
    _q = q.trim();
    setState(() => _loading = true);
    try {
      final res = await ref
          .read(posRepositoryProvider)
          .productsPage(q: _q, page: page);
      if (mounted) {
        setState(() {
          _items = res.items;
          _page = res.page;
          _lastPage = res.lastPage;
          _total = res.total;
          _loading = false;
          _error = null;
        });
        if (_scroll.hasClients) _scroll.jumpTo(0);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final picking = widget.onPick != null;
    final me = ref.watch(authControllerProvider).me;
    final canCreate = me?.can('products.create') ?? false;
    final canEditPhoto = !picking && (me?.can('products.edit') ?? false);
    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: Text(picking ? 'Agregar producto' : 'Productos')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              heroTag: 'fab-products',
              backgroundColor: ModuleColors.soft(ModuleColors.products),
              foregroundColor: ModuleColors.onSoft(ModuleColors.products),
              onPressed: _newProduct,
              icon: const Icon(Icons.add),
              label: const Text('Nuevo'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, código o SKU',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () {
                    _search.clear();
                    _load('');
                  },
                ),
              ),
              textInputAction: TextInputAction.search,
              onChanged: _onSearchChanged,
              onSubmitted: _load,
            ),
          ),
          if (!_loading && _error == null && _items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '${_rangeLabel()} de $_total producto${_total == 1 ? '' : 's'}'
                  '${_q.isNotEmpty ? ' para «$_q»' : ''}',
                  style: const TextStyle(color: Colors.black54, fontSize: 12),
                ),
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(child: Text(_error!))
                : _items.isEmpty
                ? const Center(child: Text('Sin productos.'))
                : ListView.separated(
                    controller: _scroll,
                    // Espacio final para que el FAB no tape el último ítem.
                    padding: const EdgeInsets.only(bottom: 80),
                    itemCount: _items.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, i) {
                      final p = _items[i];
                      final low = p.currentStock <= 0;
                      final busy = _photoBusyId == p.id;
                      return ListTile(
                        leading: picking
                            ? null
                            : Tooltip(
                                message: canEditPhoto
                                    ? (p.imageUrl == null
                                          ? 'Agregar foto'
                                          : 'Cambiar foto')
                                    : p.name,
                                child: InkWell(
                                  onTap: canEditPhoto && !busy
                                      ? () => _changePhoto(p)
                                      : null,
                                  borderRadius: BorderRadius.circular(12),
                                  child: ProductThumb(
                                    imageUrl: p.imageUrl,
                                    showBadge: canEditPhoto,
                                    busy: busy,
                                  ),
                                ),
                              ),
                        title: Text(p.name),
                        subtitle: Text(
                          '${p.sku ?? ''}  ·  Stock: ${qty(p.currentStock)} ${p.unit ?? ''}',
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              money(p.price),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (picking) ...[
                              const SizedBox(width: 2),
                              IconButton(
                                tooltip: 'Ver ficha y foto',
                                visualDensity: VisualDensity.compact,
                                icon: const Icon(
                                  Icons.info_outline,
                                  color: Colors.black45,
                                ),
                                onPressed: () => _openDetail(p),
                              ),
                              IconButton(
                                tooltip: 'Agregar',
                                visualDensity: VisualDensity.compact,
                                icon: Icon(
                                  Icons.add_circle,
                                  color: low && widget.requireStock
                                      ? Colors.black26
                                      : Theme.of(context).colorScheme.primary,
                                ),
                                onPressed: () => _pick(p),
                              ),
                            ] else ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.chevron_right,
                                color: low ? Colors.red : Colors.black26,
                              ),
                            ],
                          ],
                        ),
                        // En POS/compra: tocar agrega directo; mantener
                        // pulsado abre la ficha (stock, ajustar, etc.).
                        onTap: () => picking ? _pick(p) : _openDetail(p),
                        onLongPress: picking ? () => _openDetail(p) : null,
                      );
                    },
                  ),
          ),
        ],
      ),
      // Paginador como barra inferior: el FAB queda por encima y no lo tapa.
      bottomNavigationBar: !_loading && _error == null && _lastPage > 1
          ? _Pager(page: _page, lastPage: _lastPage, onChanged: _goTo)
          : null,
    );
  }

  String _rangeLabel() {
    if (_items.isEmpty) return '0';
    final start = (_page - 1) * 30 + 1;
    return '$start–${start + _items.length - 1}';
  }
}

/// Barra de paginación: progreso, ⏮ ‹ píldora "Página X de Y" › ⏭.
/// La píldora abre un selector para saltar a cualquier página (útil con
/// muchos productos). Toma el color del módulo Inventario.
class _Pager extends StatelessWidget {
  final int page;
  final int lastPage;
  final ValueChanged<int> onChanged;
  const _Pager({
    required this.page,
    required this.lastPage,
    required this.onChanged,
  });

  static const _color = ModuleColors.products;

  Future<void> _jump(BuildContext context) async {
    final target = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Ir a la página',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 10),
              // Rejilla de números: con pocas páginas entran todas de un vistazo.
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 1; i <= lastPage; i++)
                        ChoiceChip(
                          label: Text('$i'),
                          selected: i == page,
                          selectedColor: ModuleColors.soft(_color),
                          labelStyle: TextStyle(
                            fontWeight: FontWeight.w700,
                            color: i == page
                                ? ModuleColors.onSoft(_color)
                                : Colors.black87,
                          ),
                          onSelected: (_) => Navigator.pop(ctx, i),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (target != null && target != page) onChanged(target);
  }

  @override
  Widget build(BuildContext context) {
    final onColor = ModuleColors.onSoft(_color);
    final first = page <= 1;
    final last = page >= lastPage;

    Widget arrow(
      String tooltip,
      IconData icon,
      bool disabled,
      VoidCallback onTap, {
      bool filled = false,
    }) => IconButton(
      tooltip: tooltip,
      visualDensity: VisualDensity.compact,
      style: filled
          ? IconButton.styleFrom(
              backgroundColor: disabled
                  ? Colors.black.withValues(alpha: .05)
                  : ModuleColors.soft(_color),
              foregroundColor: disabled ? Colors.black26 : onColor,
              shape: const CircleBorder(),
            )
          : null,
      color: disabled ? Colors.black26 : onColor.withValues(alpha: .8),
      icon: Icon(icon, size: filled ? 22 : 20),
      onPressed: disabled ? null : onTap,
    );

    return Material(
      elevation: 6,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Progreso: qué parte del listado se está viendo.
            LinearProgressIndicator(
              value: lastPage <= 0 ? 0 : page / lastPage,
              minHeight: 3,
              backgroundColor: ModuleColors.soft(_color),
              color: _color,
            ),
            // Compacto: a 360 dp caben los 4 botones + la píldora; esta va en
            // Expanded para que nunca desborde (ver rodex-debug-overflow-anr).
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              child: Row(
                children: [
                  arrow('Primera', Icons.first_page, first, () => onChanged(1)),
                  arrow(
                    'Anterior',
                    Icons.chevron_left,
                    first,
                    () => onChanged(page - 1),
                    filled: true,
                  ),
                  Expanded(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(20),
                      onTap: lastPage > 1 ? () => _jump(context) : null,
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 6),
                        padding: const EdgeInsets.symmetric(vertical: 7),
                        decoration: BoxDecoration(
                          color: ModuleColors.soft(_color),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Flexible(
                              child: Text(
                                'Página $page de $lastPage',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  color: onColor,
                                ),
                              ),
                            ),
                            if (lastPage > 1) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.unfold_more,
                                size: 16,
                                color: onColor.withValues(alpha: .7),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  arrow(
                    'Siguiente',
                    Icons.chevron_right,
                    last,
                    () => onChanged(page + 1),
                    filled: true,
                  ),
                  arrow(
                    'Última',
                    Icons.last_page,
                    last,
                    () => onChanged(lastPage),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
