import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../pos/pos_repository.dart';
import 'new_product_screen.dart';
import 'product_detail_screen.dart';

/// Buscador de productos reutilizable. Si [onPick] está definido, al tocar un
/// producto lo devuelve (para el POS); si no, es solo consulta.
class ProductsScreen extends ConsumerStatefulWidget {
  final void Function(Product)? onPick;
  // Exige stock > 0 para elegir (POS). En false permite elegir sin stock
  // (p. ej. al crear una orden de compra).
  final bool requireStock;
  /// Oculta el "Stock inicial" en el alta de producto (flujos de compra).
  final bool hideInitialStock;

  const ProductsScreen(
      {super.key,
      this.onPick,
      this.requireStock = true,
      this.hideInitialStock = false});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _search = TextEditingController();
  List<Product> _items = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  /// Selección directa desde la lista (POS/compra): agrega el producto sin abrir
  /// la ficha. Respeta el requisito de stock del modo actual.
  void _pick(Product p) {
    if (widget.requireStock && p.currentStock <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${p.name}: sin stock disponible.')));
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
              NewProductScreen(hideInitialStock: widget.hideInitialStock)),
    );
    if (product == null) return;
    if (widget.onPick != null) {
      widget.onPick!(product);
    } else {
      _load(_search.text);
    }
  }

  Future<void> _load(String q) async {
    setState(() => _loading = true);
    try {
      final items = await ref.read(posRepositoryProvider).products(q: q);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
          _error = null;
        });
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
    final canCreate =
        ref.watch(authControllerProvider).me?.can('products.create') ?? false;
    return Scaffold(
      appBar: AppBar(title: Text(picking ? 'Agregar producto' : 'Productos')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
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
              onSubmitted: _load,
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
                            itemCount: _items.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final p = _items[i];
                              final low = p.currentStock <= 0;
                              return ListTile(
                                title: Text(p.name),
                                subtitle: Text(
                                    '${p.sku ?? ''}  ·  Stock: ${qty(p.currentStock)} ${p.unit ?? ''}'),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(money(p.price),
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w700)),
                                    if (picking) ...[
                                      const SizedBox(width: 2),
                                      IconButton(
                                        tooltip: 'Ver ficha y foto',
                                        visualDensity: VisualDensity.compact,
                                        icon: const Icon(Icons.info_outline,
                                            color: Colors.black45),
                                        onPressed: () => _openDetail(p),
                                      ),
                                      IconButton(
                                        tooltip: 'Agregar',
                                        visualDensity: VisualDensity.compact,
                                        icon: Icon(
                                          Icons.add_circle,
                                          color: low && widget.requireStock
                                              ? Colors.black26
                                              : Theme.of(context)
                                                  .colorScheme
                                                  .primary,
                                        ),
                                        onPressed: () => _pick(p),
                                      ),
                                    ] else ...[
                                      const SizedBox(width: 4),
                                      Icon(Icons.chevron_right,
                                          color:
                                              low ? Colors.red : Colors.black26),
                                    ],
                                  ],
                                ),
                                // En POS/compra: tocar agrega directo; mantener
                                // pulsado abre la ficha (stock, ajustar, etc.).
                                onTap: () =>
                                    picking ? _pick(p) : _openDetail(p),
                                onLongPress:
                                    picking ? () => _openDetail(p) : null,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
