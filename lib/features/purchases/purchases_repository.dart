import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';

/// Resumen de una orden de compra por recibir.
class PoSummary {
  final int id;
  final String code;
  final String? supplier;
  final String status; // sent | partial
  final String? date;
  final double total;

  PoSummary({
    required this.id,
    required this.code,
    this.supplier,
    required this.status,
    this.date,
    required this.total,
  });

  factory PoSummary.fromJson(Map<String, dynamic> j) => PoSummary(
        id: j['id'] as int,
        code: j['code'] as String,
        supplier: j['supplier'] as String?,
        status: (j['status'] ?? '') as String,
        date: j['date'] as String?,
        total: (j['total'] as num?)?.toDouble() ?? 0,
      );
}

/// Línea de una OC (con lo pendiente por recibir).
class PoItem {
  final int poItemId;
  final String? product;
  final String? unit;
  final double ordered;
  final double received;
  final double pending;
  final double unitCost;

  PoItem({
    required this.poItemId,
    this.product,
    this.unit,
    required this.ordered,
    required this.received,
    required this.pending,
    required this.unitCost,
  });

  factory PoItem.fromJson(Map<String, dynamic> j) => PoItem(
        poItemId: j['po_item_id'] as int,
        product: j['product'] as String?,
        unit: j['unit'] as String?,
        ordered: (j['ordered'] as num?)?.toDouble() ?? 0,
        received: (j['received'] as num?)?.toDouble() ?? 0,
        pending: (j['pending'] as num?)?.toDouble() ?? 0,
        unitCost: (j['unit_cost'] as num?)?.toDouble() ?? 0,
      );
}

class WarehouseOption {
  final int id;
  final String name;
  WarehouseOption({required this.id, required this.name});
  factory WarehouseOption.fromJson(Map<String, dynamic> j) =>
      WarehouseOption(id: j['id'] as int, name: (j['name'] ?? '') as String);
}

/// Detalle de una OC para la recepción.
class PoDetail {
  final int id;
  final String code;
  final String? supplier;
  final String status;
  final List<PoItem> items;
  final List<WarehouseOption> warehouses;

  PoDetail({
    required this.id,
    required this.code,
    this.supplier,
    required this.status,
    required this.items,
    required this.warehouses,
  });

  factory PoDetail.fromJson(Map<String, dynamic> j) => PoDetail(
        id: j['id'] as int,
        code: j['code'] as String,
        supplier: j['supplier'] as String?,
        status: (j['status'] ?? '') as String,
        items: ((j['items'] as List?) ?? [])
            .map((e) => PoItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        warehouses: ((j['warehouses'] as List?) ?? [])
            .map((e) => WarehouseOption.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Proveedor (para el directorio y alta rápida).
class Supplier {
  final int id;
  final String name;
  final String? nit;
  final String? contactName;
  final String? phone;
  final String? email;

  Supplier({
    required this.id,
    required this.name,
    this.nit,
    this.contactName,
    this.phone,
    this.email,
  });

  factory Supplier.fromJson(Map<String, dynamic> j) => Supplier(
        id: j['id'] as int,
        name: j['name'] as String,
        nit: j['nit'] as String?,
        contactName: j['contact_name'] as String?,
        phone: j['phone'] as String?,
        email: j['email'] as String?,
      );
}

class PurchasesRepository {
  final ApiClient _api;
  PurchasesRepository(this._api);

  Future<List<Supplier>> suppliers({String q = ''}) async {
    final data = await _api.get('/suppliers', query: {'q': q});
    return (((data as Map<String, dynamic>)['data'] as List?) ?? [])
        .map((e) => Supplier.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Supplier> createSupplier({
    required String name,
    String? nit,
    String? contactName,
    String? phone,
    String? email,
  }) async {
    final data = await _api.post('/suppliers', body: {
      'name': name,
      'nit': ?nit,
      'contact_name': ?contactName,
      'phone': ?phone,
      'email': ?email,
    });
    return Supplier.fromJson((data as Map<String, dynamic>)['data']);
  }

  /// Compra directa (contado): registra la compra, suma stock y paga desde caja.
  /// Devuelve un resumen (código, proveedor, total). `items` = [{product_id, quantity, unit_cost}].
  Future<Map<String, dynamic>> directPurchase({
    required int supplierId,
    required int warehouseId,
    required List<Map<String, dynamic>> items,
    String? invoiceNumber,
    String? notes,
  }) async {
    final data = await _api.post('/purchases/direct', body: {
      'supplier_id': supplierId,
      'warehouse_id': warehouseId,
      'items': items,
      'invoice_number': ?invoiceNumber,
      'notes': ?notes,
    });
    return (data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
  }

  /// Crea una orden de compra (queda 'sent', lista para recibir).
  /// `items` = [{product_id, quantity, unit_cost}].
  Future<PoSummary> createPurchaseOrder({
    required int supplierId,
    required List<Map<String, dynamic>> items,
    String? expectedDate,
    String? notes,
  }) async {
    final data = await _api.post('/purchase-orders', body: {
      'supplier_id': supplierId,
      'items': items,
      'expected_date': ?expectedDate,
      'notes': ?notes,
    });
    return PoSummary.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<List<PoSummary>> receivableOrders() async {
    final data = await _api.get('/purchase-orders');
    return (((data as Map<String, dynamic>)['data'] as List?) ?? [])
        .map((e) => PoSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<PoDetail> orderDetail(int id) async {
    final data = await _api.get('/purchase-orders/$id');
    return PoDetail.fromJson((data as Map<String, dynamic>)['data']);
  }

  /// Recibe mercadería contra la OC. `items` = [{po_item_id, quantity}].
  /// Devuelve el mensaje de confirmación (recepción + compra generada).
  Future<String> receive(
    int id, {
    required int warehouseId,
    required List<Map<String, dynamic>> items,
    String? invoiceNumber,
    String? notes,
  }) async {
    final data = await _api.post('/purchase-orders/$id/receive', body: {
      'warehouse_id': warehouseId,
      'items': items,
      'invoice_number': ?invoiceNumber,
      'notes': ?notes,
    });
    final d = (data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    return (d['message'] ?? 'Recepción registrada') as String;
  }
}

final purchasesRepositoryProvider = Provider<PurchasesRepository>(
  (ref) => PurchasesRepository(ref.read(apiClientProvider)),
);
