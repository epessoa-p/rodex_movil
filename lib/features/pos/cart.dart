import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';

class CartLine {
  final Product product;
  final double quantity;

  /// Descuento por línea (monto en la moneda), aplicado a este ítem.
  final double discount;

  CartLine(this.product, this.quantity, {this.discount = 0});

  /// Importe bruto de la línea (sin descuento).
  double get gross => product.price * quantity;

  /// Importe de la línea con el descuento aplicado (nunca negativo).
  double get subtotal {
    final v = gross - discount;
    return v < 0 ? 0 : v;
  }

  CartLine copyWith({double? quantity, double? discount}) =>
      CartLine(product, quantity ?? this.quantity,
          discount: discount ?? this.discount);
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

  /// Fija el descuento (monto) de una línea; se acota entre 0 y el bruto.
  void setDiscount(int productId, double discount) {
    state = [
      for (final l in state)
        if (l.product.id == productId)
          l.copyWith(discount: discount.clamp(0, l.gross).toDouble())
        else
          l,
    ];
  }

  void remove(int productId) {
    state = state.where((l) => l.product.id != productId).toList();
  }

  void clear() => state = const [];

  /// Total neto (suma de líneas con su descuento aplicado).
  double get total => state.fold(0, (sum, l) => sum + l.subtotal);

  /// Suma de descuentos por línea (para mostrarlo en el resumen).
  double get lineDiscountTotal =>
      state.fold(0, (sum, l) => sum + l.discount.clamp(0, l.gross));

  int get count => state.length;

  List<Map<String, dynamic>> toItems() => [
        for (final l in state)
          {
            'product_id': l.product.id,
            'quantity': l.quantity,
            'unit_price': l.product.price,
            'discount': l.discount.clamp(0, l.gross),
          }
      ];
}

final cartProvider = StateNotifierProvider<Cart, List<CartLine>>((ref) => Cart());
