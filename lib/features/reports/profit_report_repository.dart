import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import 'report_period.dart';

double _d(dynamic v) => (v as num?)?.toDouble() ?? 0;

/// Qué incluir en el reporte de ganancias.
enum ProfitScope { all, sales, workshop }

const profitScopeLabels = {
  ProfitScope.all: 'Ambos',
  ProfitScope.sales: 'Ventas',
  ProfitScope.workshop: 'Taller',
};

class ProfitDay {
  final String date;
  final double revenue;
  final double cost;
  final double profit;
  ProfitDay(this.date, this.revenue, this.cost, this.profit);
  factory ProfitDay.fromJson(Map<String, dynamic> j) => ProfitDay(
    (j['date'] ?? '') as String,
    _d(j['revenue']),
    _d(j['cost']),
    _d(j['profit']),
  );
}

class ProfitProduct {
  final String name;
  final double quantity;
  final double revenue;
  final double profit;
  final double margin;
  ProfitProduct({
    required this.name,
    required this.quantity,
    required this.revenue,
    required this.profit,
    required this.margin,
  });
  factory ProfitProduct.fromJson(Map<String, dynamic> j) => ProfitProduct(
    name: (j['name'] ?? '') as String,
    quantity: _d(j['quantity']),
    revenue: _d(j['revenue']),
    profit: _d(j['profit']),
    margin: _d(j['margin']),
  );
}

/// Una venta u OT del período con su ganancia.
class ProfitTransaction {
  final String type; // sale | ot
  final int id;
  final String code;
  final String date; // yyyy-mm-dd HH:mm
  final String? client;
  final double revenue;
  final double cost;
  final double profit;
  final double margin;

  /// Venta rápida sin costo conocido que no se sumó.
  final double quick;
  final bool estimated;

  ProfitTransaction({
    required this.type,
    required this.id,
    required this.code,
    required this.date,
    this.client,
    required this.revenue,
    required this.cost,
    required this.profit,
    required this.margin,
    this.quick = 0,
    this.estimated = false,
  });

  bool get isOt => type == 'ot';

  factory ProfitTransaction.fromJson(Map<String, dynamic> j) =>
      ProfitTransaction(
        type: (j['type'] ?? 'sale') as String,
        id: (j['id'] as num?)?.toInt() ?? 0,
        code: (j['code'] ?? '') as String,
        date: (j['date'] ?? '') as String,
        client: j['client'] as String?,
        revenue: _d(j['revenue']),
        cost: _d(j['cost']),
        profit: _d(j['profit']),
        margin: _d(j['margin']),
        quick: _d(j['quick']),
        estimated: (j['estimated'] ?? false) as bool,
      );
}

/// Ganancias (precio − costo) de ventas y taller en un período.
class ProfitReport {
  final String from;
  final String to;

  // Totales
  final double revenue;
  final double cost;
  final double commission;
  final double profit;
  final double margin;

  // Ventas
  final bool salesEnabled;
  final double salesRevenue;
  final double salesCost;
  final double salesProfit;
  final double salesMargin;
  final int salesCount;
  final double returnsRevenue;

  // Taller
  final bool workshopEnabled;
  final double labor;
  final double parts;
  final double partsCost;
  final double commissionPaid;
  final double commissionPending;
  final double workshopProfit;
  final double workshopMargin;
  final int workshopCount;

  // Ventas rápidas (sin costo conocido)
  final double quickRevenue;
  final int quickCount;
  final bool quickMerged;

  final List<ProfitDay> byDay;
  final List<ProfitProduct> topProducts;
  final List<ProfitProduct> lowMargin;
  final int estimatedLines;
  final List<IdName> branches;

  /// Ventas y OTs (las más recientes, hasta 300) y cuántas hay en total.
  final List<ProfitTransaction> transactions;
  final int transactionsTotal;

  ProfitReport({
    required this.from,
    required this.to,
    required this.revenue,
    required this.cost,
    required this.commission,
    required this.profit,
    required this.margin,
    required this.salesEnabled,
    required this.salesRevenue,
    required this.salesCost,
    required this.salesProfit,
    required this.salesMargin,
    required this.salesCount,
    required this.returnsRevenue,
    required this.workshopEnabled,
    required this.labor,
    required this.parts,
    required this.partsCost,
    required this.commissionPaid,
    required this.commissionPending,
    required this.workshopProfit,
    required this.workshopMargin,
    required this.workshopCount,
    required this.quickRevenue,
    required this.quickCount,
    required this.quickMerged,
    required this.byDay,
    required this.topProducts,
    required this.lowMargin,
    required this.estimatedLines,
    this.branches = const [],
    this.transactions = const [],
    this.transactionsTotal = 0,
  });

  factory ProfitReport.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> m(String k) =>
        (j[k] as Map?)?.cast<String, dynamic>() ?? const {};
    List<T> list<T>(String k, T Function(Map<String, dynamic>) f) =>
        ((j[k] as List?) ?? [])
            .map((e) => f((e as Map).cast<String, dynamic>()))
            .toList();
    final t = m('totals'), s = m('sales'), w = m('workshop'), q = m('quick');
    return ProfitReport(
      from: (j['from'] ?? '') as String,
      to: (j['to'] ?? '') as String,
      revenue: _d(t['revenue']),
      cost: _d(t['cost']),
      commission: _d(t['commission']),
      profit: _d(t['profit']),
      margin: _d(t['margin']),
      salesEnabled: (s['enabled'] ?? true) as bool,
      salesRevenue: _d(s['revenue']),
      salesCost: _d(s['cost']),
      salesProfit: _d(s['profit']),
      salesMargin: _d(s['margin']),
      salesCount: (s['count'] as num?)?.toInt() ?? 0,
      returnsRevenue: _d(s['returns_revenue']),
      workshopEnabled: (w['enabled'] ?? true) as bool,
      labor: _d(w['labor']),
      parts: _d(w['parts']),
      partsCost: _d(w['parts_cost']),
      commissionPaid: _d(w['commission_paid']),
      commissionPending: _d(w['commission_pending']),
      workshopProfit: _d(w['profit']),
      workshopMargin: _d(w['margin']),
      workshopCount: (w['count'] as num?)?.toInt() ?? 0,
      quickRevenue: _d(q['revenue']),
      quickCount: (q['count'] as num?)?.toInt() ?? 0,
      quickMerged: (q['merged'] ?? false) as bool,
      byDay: list('by_day', ProfitDay.fromJson),
      topProducts: list('top_products', ProfitProduct.fromJson),
      lowMargin: list('low_margin', ProfitProduct.fromJson),
      estimatedLines: (j['estimated_lines'] as num?)?.toInt() ?? 0,
      branches: list('branches', IdName.fromJson),
      transactions: list('transactions', ProfitTransaction.fromJson),
      transactionsTotal: (j['transactions_total'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Filtros del reporte (clave del provider).
class ProfitQuery {
  final ReportPeriod period;
  final int? branchId;
  final ProfitScope scope;
  final bool mergeQuick;
  const ProfitQuery({
    required this.period,
    this.branchId,
    this.scope = ProfitScope.all,
    this.mergeQuick = false,
  });

  ProfitQuery copyWith({
    ReportPeriod? period,
    int? Function()? branchId,
    ProfitScope? scope,
    bool? mergeQuick,
  }) => ProfitQuery(
    period: period ?? this.period,
    branchId: branchId != null ? branchId() : this.branchId,
    scope: scope ?? this.scope,
    mergeQuick: mergeQuick ?? this.mergeQuick,
  );

  Map<String, dynamic> get params => {
    ...period.query,
    'branch_id': ?branchId,
    'scope': scope.name,
    'merge_quick': mergeQuick ? 1 : 0,
  };

  @override
  bool operator ==(Object other) =>
      other is ProfitQuery &&
      other.period.key == period.key &&
      other.branchId == branchId &&
      other.scope == scope &&
      other.mergeQuick == mergeQuick;

  @override
  int get hashCode => Object.hash(period.key, branchId, scope, mergeQuick);
}

final profitReportProvider = FutureProvider.autoDispose
    .family<ProfitReport, ProfitQuery>((ref, q) async {
      final data = await ref
          .read(apiClientProvider)
          .get('/reports/profit', query: q.params);
      return ProfitReport.fromJson(
        ((data as Map)['data'] as Map).cast<String, dynamic>(),
      );
    });
