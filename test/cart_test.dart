import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/features/pos/cart.dart';

Product _p(int id, double price) =>
    Product(id: id, name: 'P$id', price: price, currentStock: 100);

void main() {
  group('Cart', () {
    test('agregar productos y calcular total', () {
      final cart = Cart();
      cart.add(_p(1, 10));
      cart.add(_p(2, 5));
      cart.add(_p(1, 10)); // repetido: sube cantidad, no duplica línea

      expect(cart.count, 2);
      expect(cart.total, 25); // (10*2) + (5*1)
    });

    test('cambiar cantidad y quitar', () {
      final cart = Cart();
      cart.add(_p(1, 10));
      cart.setQuantity(1, 3);
      expect(cart.total, 30);

      cart.setQuantity(1, 0); // 0 => elimina la línea
      expect(cart.count, 0);
      expect(cart.total, 0);
    });

    test('toItems produce el payload del endpoint', () {
      final cart = Cart();
      cart.add(_p(7, 12.5));
      cart.setQuantity(7, 2);

      final items = cart.toItems();
      expect(items, [
        {'product_id': 7, 'quantity': 2.0, 'unit_price': 12.5}
      ]);
    });

    test('clear vacía el carrito', () {
      final cart = Cart();
      cart.add(_p(1, 10));
      cart.clear();
      expect(cart.count, 0);
    });
  });
}
