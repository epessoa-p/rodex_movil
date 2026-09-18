import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/features/pos/pos_repository.dart';

/// Backend viejo: /products devuelve todo (sin `meta`).
class _OldApi extends ApiClient {
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => {
    'data': [
      for (var i = 1; i <= 32; i++)
        {'id': i, 'name': 'P$i', 'price': 1, 'current_stock': 1},
    ],
  };
}

/// Backend nuevo: ya pagina en el servidor.
class _NewApi extends ApiClient {
  @override
  Future<dynamic> get(String path, {Map<String, dynamic>? query}) async => {
    'data': [
      for (var i = 1; i <= 30; i++)
        {'id': i, 'name': 'P$i', 'price': 1, 'current_stock': 1},
    ],
    'meta': {'current_page': 1, 'last_page': 2, 'per_page': 30, 'total': 32},
  };
}

void main() {
  test('Sin meta (backend viejo) la app pagina de a 30 localmente', () async {
    final repo = PosRepository(_OldApi());
    final p1 = await repo.productsPage(page: 1);
    expect(p1.items.length, 30);
    expect(p1.total, 32);
    expect(p1.hasMore, isTrue);
    final p2 = await repo.productsPage(page: 2);
    expect(p2.items.length, 2);
    expect(p2.items.first.name, 'P31');
    expect(p2.hasMore, isFalse);
  });

  test('Con meta (backend nuevo) respeta la paginación del servidor', () async {
    final p1 = await PosRepository(_NewApi()).productsPage(page: 1);
    expect(p1.items.length, 30);
    expect(p1.lastPage, 2);
    expect(p1.total, 32);
    expect(p1.hasMore, isTrue);
  });
}
