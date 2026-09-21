import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

class CategoryValuation {
  final String name;
  final int products;
  final double units;
  final double valueCost;
  final double valuePrice;
  CategoryValuation({
    required this.name,
    required this.products,
    required this.units,
    required this.valueCost,
    required this.valuePrice,
  });
  factory CategoryValuation.fromJson(Map<String, dynamic> j) =>
      CategoryValuation(
        name: (j['name'] ?? '') as String,
        products: (j['products'] as num?)?.toInt() ?? 0,
        units: _d(j['units']),
        valueCost: _d(j['value_cost']),
        valuePrice: _d(j['value_price']),
      );
}

class LowStockRow {
  final int id;
  final String name;
  final String? sku;
  final double stock;
  final int minStock;
  final String? unit;
  LowStockRow({
    required this.id,
    required this.name,
    this.sku,
    required this.stock,
    required this.minStock,
    this.unit,
  });
  factory LowStockRow.fromJson(Map<String, dynamic> j) => LowStockRow(
    id: j['id'] as int,
    name: (j['name'] ?? '') as String,
    sku: j['sku'] as String?,
    stock: _d(j['stock']),
    minStock: (j['min_stock'] as num?)?.toInt() ?? 0,
    unit: j['unit'] as String?,
  );
}

/// Valorización del inventario (consolidada o por almacén).
class InventoryReport {
  final int productCount;
  final double totalUnits;
  final double valueCost;
  final double valuePrice;
  final double potentialProfit;
  final List<CategoryValuation> byCategory;
  final List<LowStockRow> lowStock;
  final int? warehouseId;
  final List<IdName> warehouses;

  InventoryReport({
    required this.productCount,
    required this.totalUnits,
    required this.valueCost,
    required this.valuePrice,
    required this.potentialProfit,
    required this.byCategory,
    required this.lowStock,
    this.warehouseId,
    required this.warehouses,
  });

  factory InventoryReport.fromJson(Map<String, dynamic> j) {
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List?) ?? [])
            .map((e) => f(e as Map<String, dynamic>))
            .toList();
    return InventoryReport(
      productCount: (j['product_count'] as num?)?.toInt() ?? 0,
      totalUnits: _d(j['total_units']),
      valueCost: _d(j['value_cost']),
      valuePrice: _d(j['value_price']),
      potentialProfit: _d(j['potential_profit']),
      byCategory: list('by_category', CategoryValuation.fromJson),
      lowStock: list('low_stock', LowStockRow.fromJson),
      warehouseId: (j['warehouse_id'] as num?)?.toInt(),
      warehouses: list('warehouses', IdName.fromJson),
    );
  }
}

class InventoryReportRepository {
  final ApiClient _api;
  InventoryReportRepository(this._api);

  Future<InventoryReport> get({int? warehouseId}) async {
    final data = await _api.get(
      '/reports/inventory',
      query: {'warehouse_id': ?warehouseId},
    );
    return InventoryReport.fromJson((data as Map<String, dynamic>)['data']);
  }
}

final inventoryReportRepositoryProvider = Provider(
  (ref) => InventoryReportRepository(ref.read(apiClientProvider)),
);

/// Por almacén (0 = consolidado).
final inventoryReportProvider = FutureProvider.family<InventoryReport, int>(
  (ref, whId) => ref
      .read(inventoryReportRepositoryProvider)
      .get(warehouseId: whId == 0 ? null : whId),
);
