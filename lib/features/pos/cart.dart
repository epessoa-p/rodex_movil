import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';

class CartLine {
  final Product product;
  final double quantity;

  /// Descuento por línea (monto en la moneda), aplicado a este ítem.
  final double discount;

  /// Venta rápida: el producto no está en el inventario (solo nombre y precio).
  final bool direct;

  CartLine(
    this.product,
    this.quantity, {
    this.discount = 0,
    this.direct = false,
  });

  /// Importe bruto de la línea (sin descuento).
  double get gross => product.price * quantity;

  /// Importe de la línea con el descuento aplicado (nunca negativo).
  double get subtotal {
    final v = gross - discount;
    return v < 0 ? 0 : v;
  }

  CartLine copyWith({double? quantity, double? discount}) => CartLine(
    product,
    quantity ?? this.quantity,
    discount: discount ?? this.discount,
    direct: direct,
  );
}

/// Carrito del POS (venta en construcción).
class Cart extends StateNotifier<List<CartLine>> {
  Cart() : super(const []);

  /// Ids negativos para las líneas de venta rápida (no chocan con productos).
  int _directSeq = 0;

  /// Venta rápida: algo que está en físico pero no en el inventario. Se vende
  /// con este nombre y precio; si el nombre coincide con un producto
  /// registrado, el servidor descuenta su stock (igual que el POS web).
  void addDirect({
    required String name,
    required double price,
    double quantity = 1,
  }) {
    final product = Product(
      id: -(++_directSeq),
      name: name,
      price: price,
      currentStock: 0,
    );
    state = [...state, CartLine(product, quantity, direct: true)];
  }

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
      if (l.direct)
        {
          'direct': 1,
          'name': l.product.name,
          'quantity': l.quantity,
          'unit_price': l.product.price,
          'discount': l.discount.clamp(0, l.gross),
        }
      else
        {
          'product_id': l.product.id,
          'quantity': l.quantity,
          'unit_price': l.product.price,
          'discount': l.discount.clamp(0, l.gross),
        },
  ];
}

final cartProvider = StateNotifierProvider<Cart, List<CartLine>>(
  (ref) => Cart(),
);
