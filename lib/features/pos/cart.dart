import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';

class CartLine {
  final Product product;
  final double quantity;

  CartLine(this.product, this.quantity);

  double get subtotal => product.price * quantity;

  CartLine copyWith({double? quantity}) =>
      CartLine(product, quantity ?? this.quantity);
}

/// Carrito del POS (venta en construcción).
class Cart extends StateNotifier<List<CartLine>> {
  Cart() : super(const []);

  void add(Product product) {
    final idx = state.indexWhere((l) => l.product.id == product.id);
    if (idx >= 0) {
      setQuantity(product.id, state[idx].quantity + 1);
    } else {
      state = [...state, CartLine(product, 1)];
    }
  }

  void setQuantity(int productId, double qty) {
    if (qty <= 0) {
      remove(productId);
      return;
    }
    state = [
      for (final l in state)
        if (l.product.id == productId) l.copyWith(quantity: qty) else l,
    ];
  }

  void remove(int productId) {
    state = state.where((l) => l.product.id != productId).toList();
  }

  void clear() => state = const [];

  double get total => state.fold(0, (sum, l) => sum + l.subtotal);
  int get count => state.length;

  List<Map<String, dynamic>> toItems() => [
        for (final l in state)
          {
            'product_id': l.product.id,
            'quantity': l.quantity,
            'unit_price': l.product.price,
          }
      ];
}

final cartProvider = StateNotifierProvider<Cart, List<CartLine>>((ref) => Cart());
