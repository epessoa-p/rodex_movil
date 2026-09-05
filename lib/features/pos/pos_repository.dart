import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

/// Acceso a los endpoints del POS (productos, clientes, caja, ventas).
class PosRepository {
  final ApiClient _api;
  PosRepository(this._api);

  Future<List<Product>> products({String q = ''}) async {
    final data = await _api.get('/products', query: {'q': q});
    return _list(data).map((e) => Product.fromJson(e)).toList();
  }

  /// Catálogos para el alta rápida de producto (categorías, marcas, almacenes).
  Future<ProductCatalogs> productFormData() async {
    final data = await _api.get('/product-form-data');
    final d = (data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    List<IdName> opts(String k) => ((d[k] as List?) ?? [])
        .map((e) => IdName.fromJson(e as Map<String, dynamic>))
        .toList();
    return ProductCatalogs(
      categories: opts('categories'),
      brands: opts('brands'),
      warehouses: opts('warehouses'),
    );
  }

  /// Alta rápida de producto. Devuelve el producto creado (para agregarlo al POS).
  /// Si [photoPath] está definido, se sube la foto (multipart) como principal.
  Future<Product> createProduct({
    required String name,
    required double price,
    double? cost,
    String? unit,
    String? barcode,
    int? categoryId,
    int? brandId,
    double? initialStock,
    int? warehouseId,
    String? photoPath,
  }) async {
    final fields = <String, dynamic>{
      'name': name,
      'price': price,
      'cost': ?cost,
      'unit': ?unit,
      'barcode': ?barcode,
      'category_id': ?categoryId,
      'brand_id': ?brandId,
      'initial_stock': ?initialStock,
      'warehouse_id': ?warehouseId,
    };

    Object body = fields;
    if (photoPath != null) {
      final form = FormData.fromMap(fields);
      form.files.add(MapEntry(
        'photo',
        await MultipartFile.fromFile(photoPath,
            filename: photoPath.split(RegExp(r'[\\/]')).last),
      ));
      body = form;
    }

    final data = await _api.post('/products', body: body);
    return Product.fromJson((data as Map<String, dynamic>)['data']);
  }

  /// Ficha completa de un producto (precio, stock por almacén, origen, modelos).
  Future<ProductDetail> productDetail(int id) async {
    final data = await _api.get('/products/$id');
    return ProductDetail.fromJson((data as Map<String, dynamic>)['data']);
  }

  /// Ajuste rápido de stock: type = 'in' | 'out' | 'set'.
  Future<void> adjustStock({
    required int productId,
    required int warehouseId,
    required String type,
    required double quantity,
    String? reason,
  }) async {
    await _api.post('/products/$productId/stock-adjust', body: {
      'warehouse_id': warehouseId,
      'type': type,
      'quantity': quantity,
      'reason': ?reason,
    });
  }

  /// Busca un producto por código escaneado (barcode/sku). Devuelve el match
  /// EXACTO; si no hay exacto pero la búsqueda trae un único resultado, ese.
  Future<Product?> productByCode(String code) async {
    final term = code.trim();
    if (term.isEmpty) return null;
    final results = await products(q: term);
    if (results.isEmpty) return null;

    for (final p in results) {
      if (p.barcode != null && p.barcode!.trim() == term) return p;
    }
    for (final p in results) {
      if (p.sku != null && p.sku!.trim() == term) return p;
    }
    return results.length == 1 ? results.first : null;
  }

  Future<List<Client>> clients({String q = ''}) async {
    final data = await _api.get('/clients', query: {'q': q});
    return _list(data).map((e) => Client.fromJson(e)).toList();
  }

  Future<Client> createClient({
    required String fullName,
    String? idNumber,
    String? phone,
  }) async {
    final data = await _api.post('/clients', body: {
      'full_name': fullName,
      if (idNumber != null && idNumber.isNotEmpty) 'id_number': idNumber,
      if (phone != null && phone.isNotEmpty) 'phone': phone,
    });
    return Client.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<CashSession?> currentSession() async {
    final data = await _api.get('/cash/current-session');
    final d = (data as Map<String, dynamic>)['data'];
    return d == null ? null : CashSession.fromJson(d as Map<String, dynamic>);
  }

  Future<List<CashRegisterOption>> registers() async {
    final data = await _api.get('/cash/registers');
    return _list(data).map((e) => CashRegisterOption.fromJson(e)).toList();
  }

  Future<CashSession> openSession({
    required int cashRegisterId,
    required double openingAmount,
  }) async {
    final data = await _api.post('/cash/open', body: {
      'cash_register_id': cashRegisterId,
      'opening_amount': openingAmount,
    });
    return CashSession.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<void> closeSession({required double closingAmount}) async {
    await _api.post('/cash/close', body: {'closing_amount': closingAmount});
  }

  /// Movimientos (ingresos/gastos) de la sesión de caja abierta.
  Future<List<CashMovement>> sessionMovements() async {
    final data = await _api.get('/cash/movements');
    return _list(data).map((e) => CashMovement.fromJson(e)).toList();
  }

  /// Registra un gasto simple contra la caja abierta. Devuelve la sesión
  /// actualizada (con el nuevo esperado).
  Future<CashSession> registerExpense({
    required double amount,
    required String category, // expense_operational | expense_service | expense_transport
    String? concept,
    String method = 'efectivo',
  }) async {
    final data = await _api.post('/cash/expense', body: {
      'amount': amount,
      'category': category,
      'concept': ?concept,
      'method': method,
    });
    return CashSession.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<Sale> createSale({
    int? clientId,
    required List<Map<String, dynamic>> items,
    double discount = 0,
  }) async {
    final data = await _api.post('/sales', body: {
      'sale_type': 'cash',
      'client_id': ?clientId,
      'discount': discount,
      'items': items,
    });
    return Sale.fromJson((data as Map<String, dynamic>)['data']);
  }

  /// Historial de ventas (paginado). El backend aplica el scope de "solo las
  /// mías" salvo permiso 'sales.view-all-records'.
  Future<SalesPage> sales({
    int page = 1,
    String q = '',
    String? dateFrom,
    String? dateTo,
  }) async {
    final data = await _api.get('/sales', query: {
      'page': page,
      if (q.isNotEmpty) 'q': q,
      'date_from': ?dateFrom,
      'date_to': ?dateTo,
    }) as Map<String, dynamic>;

    final items = _list(data).map((e) => Sale.fromJson(e)).toList();
    final meta = (data['meta'] as Map<String, dynamic>?) ?? const {};
    final current = (meta['current_page'] as int?) ?? page;
    final last = (meta['last_page'] as int?) ?? current;

    return SalesPage(items: items, page: current, hasMore: current < last);
  }

  /// Resumen de ventas del día (para el inicio).
  Future<DaySummary> todaySummary() async {
    final data = await _api.get('/sales/summary');
    return DaySummary.fromJson((data as Map<String, dynamic>)['data']);
  }

  /// Detalle completo de una venta (con items) para mostrar el recibo.
  Future<Sale> saleById(int id) async {
    final data = await _api.get('/sales/$id');
    return Sale.fromJson((data as Map<String, dynamic>)['data']);
  }

  List<Map<String, dynamic>> _list(dynamic data) =>
      (((data as Map<String, dynamic>)['data'] as List?) ?? [])
          .cast<Map<String, dynamic>>();
}

/// Catálogos para el alta rápida de producto.
class ProductCatalogs {
  final List<IdName> categories;
  final List<IdName> brands;
  final List<IdName> warehouses;
  const ProductCatalogs({
    required this.categories,
    required this.brands,
    required this.warehouses,
  });
}

/// Página de resultados del historial de ventas (para el scroll infinito).
class SalesPage {
  final List<Sale> items;
  final int page;
  final bool hasMore;
  const SalesPage({required this.items, required this.page, required this.hasMore});
}

final posRepositoryProvider = Provider<PosRepository>(
  (ref) => PosRepository(ref.read(apiClientProvider)),
);

/// Sesión de caja actual (para la pantalla de inicio y el POS).
final cashSessionProvider = FutureProvider<CashSession?>(
  (ref) => ref.read(posRepositoryProvider).currentSession(),
);

/// Resumen de ventas del día (para la pantalla de inicio).
final todaySummaryProvider = FutureProvider<DaySummary>(
  (ref) => ref.read(posRepositoryProvider).todaySummary(),
);
