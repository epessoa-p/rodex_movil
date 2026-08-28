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
  const ProductsScreen({super.key, this.onPick, this.requireStock = true});

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

  /// Abre la ficha del producto. En modo "picking" la ficha ofrece "Agregar";
  /// si el usuario agrega, la ficha devuelve el Product y lo entregamos al POS.
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
      MaterialPageRoute(builder: (_) => const NewProductScreen()),
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
                                    const SizedBox(width: 4),
                                    Icon(Icons.chevron_right,
                                        color: low ? Colors.red : Colors.black26),
                                  ],
                                ),
                                onTap: () => _openDetail(p),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
