// Modelos de datos de la API.

double _toDouble(dynamic v) =>
    v == null ? 0 : (v is num ? v.toDouble() : double.tryParse('$v') ?? 0);

class Company {
  final int id;
  final String name;
  final String currency;
  final String? logoUrl;
  final String? themePrimary;
  final String? themeAccent;

  Company({
    required this.id,
    required this.name,
    this.currency = 'Bs',
    this.logoUrl,
    this.themePrimary,
    this.themeAccent,
  });

  factory Company.fromJson(Map<String, dynamic> j) => Company(
        id: j['id'] as int,
        name: j['name'] as String,
        currency: (j['currency'] as String?)?.trim().isNotEmpty == true
            ? (j['currency'] as String).trim()
            : 'Bs',
        logoUrl: j['logo_url'] as String?,
        themePrimary: j['theme_primary'] as String?,
        themeAccent: j['theme_accent'] as String?,
      );
}

class AppUser {
  final int id;
  final String name;
  final String? email;

  AppUser({required this.id, required this.name, this.email});

  factory AppUser.fromJson(Map<String, dynamic> j) => AppUser(
        id: j['id'] as int,
        name: j['name'] as String,
        email: j['email'] as String?,
      );
}

/// Contexto de sesión que devuelve /api/me (empresa activa, permisos, plan).
class MeContext {
  final AppUser user;
  final bool isSuperAdmin;
  final Company? company;
  final List<Company> companies; // empresas a las que pertenece el usuario
  final List<String> permissions;
  final List<String> planFeatures;

  MeContext({
    required this.user,
    required this.isSuperAdmin,
    required this.company,
    required this.companies,
    required this.permissions,
    required this.planFeatures,
  });

  bool can(String permission) => isSuperAdmin || permissions.contains(permission);
  bool canAny(List<String> perms) => isSuperAdmin || perms.any(permissions.contains);
  bool planAllows(String feature) => isSuperAdmin || planFeatures.contains(feature);

  factory MeContext.fromJson(Map<String, dynamic> j) => MeContext(
        user: AppUser.fromJson(j['user'] as Map<String, dynamic>),
        isSuperAdmin: (j['is_super_admin'] as bool?) ?? false,
        company: j['company'] == null
            ? null
            : Company.fromJson(j['company'] as Map<String, dynamic>),
        companies: ((j['companies'] as List?) ?? [])
            .map((e) => Company.fromJson(e as Map<String, dynamic>))
            .toList(),
        permissions:
            ((j['permissions'] as List?) ?? []).map((e) => e.toString()).toList(),
        planFeatures: ((j['plan']?['features'] as List?) ?? [])
            .map((e) => e.toString())
            .toList(),
      );
}

class Product {
  final int id;
  final String name;
  final String? sku;
  final String? barcode;
  final String? unit;
  final double price;
  final double currentStock;

  Product({
    required this.id,
    required this.name,
    this.sku,
    this.barcode,
    this.unit,
    required this.price,
    required this.currentStock,
  });

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: j['id'] as int,
        name: j['name'] as String,
        sku: j['sku'] as String?,
        barcode: j['barcode'] as String?,
        unit: j['unit'] as String?,
        price: _toDouble(j['price']),
        currentStock: _toDouble(j['current_stock']),
      );
}

/// Stock de un producto en un almacén (para la ficha).
class WarehouseStock {
  final int id;
  final String warehouse;
  final double qty;
  WarehouseStock({required this.id, required this.warehouse, required this.qty});

  factory WarehouseStock.fromJson(Map<String, dynamic> j) => WarehouseStock(
        id: (j['id'] as num?)?.toInt() ?? 0,
        warehouse: (j['warehouse'] ?? '') as String,
        qty: _toDouble(j['qty']),
      );
}

/// Ficha completa de un producto (precio, stock por almacén, origen, modelos).
class ProductDetail {
  final int id;
  final String name;
  final String? sku;
  final String? code;
  final String? barcode;
  final String? unit;
  final double price;
  final double currentStock;
  final String? category;
  final String? brand;
  final String? origin;
  final List<String> compatibleModels;
  final List<WarehouseStock> stockByWarehouse;

  ProductDetail({
    required this.id,
    required this.name,
    this.sku,
    this.code,
    this.barcode,
    this.unit,
    required this.price,
    required this.currentStock,
    this.category,
    this.brand,
    this.origin,
    required this.compatibleModels,
    required this.stockByWarehouse,
  });

  factory ProductDetail.fromJson(Map<String, dynamic> j) => ProductDetail(
        id: j['id'] as int,
        name: j['name'] as String,
        sku: j['sku'] as String?,
        code: j['code'] as String?,
        barcode: j['barcode'] as String?,
        unit: j['unit'] as String?,
        price: _toDouble(j['price']),
        currentStock: _toDouble(j['current_stock']),
        category: j['category'] as String?,
        brand: j['brand'] as String?,
        origin: j['origin'] as String?,
        compatibleModels: ((j['compatible_models'] as List?) ?? [])
            .map((e) => e.toString())
            .toList(),
        stockByWarehouse: ((j['stock_by_warehouse'] as List?) ?? [])
            .map((e) => WarehouseStock.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Producto ligero para el carrito (lo que el POS necesita).
  Product toProduct() => Product(
        id: id,
        name: name,
        sku: sku,
        barcode: barcode,
        unit: unit,
        price: price,
        currentStock: currentStock,
      );
}

class Client {
  final int id;
  final String fullName;
  final String? idNumber;
  final String? phone;

  Client({
    required this.id,
    required this.fullName,
    this.idNumber,
    this.phone,
  });

  factory Client.fromJson(Map<String, dynamic> j) => Client(
        id: j['id'] as int,
        fullName: j['full_name'] as String,
        idNumber: j['id_number'] as String?,
        phone: j['phone'] as String?,
      );
}

class CashSession {
  final int id;
  final String? cashRegister;
  final String? branch;
  final int? branchId;
  final double openingAmount;
  final double totalIncome;
  final double totalExpense;
  final double expectedAmount;

  CashSession({
    required this.id,
    this.cashRegister,
    this.branch,
    this.branchId,
    required this.openingAmount,
    required this.totalIncome,
    required this.totalExpense,
    required this.expectedAmount,
  });

  factory CashSession.fromJson(Map<String, dynamic> j) => CashSession(
        id: j['id'] as int,
        cashRegister: j['cash_register'] as String?,
        branch: j['branch'] as String?,
        branchId: j['branch_id'] as int?,
        openingAmount: _toDouble(j['opening_amount']),
        totalIncome: _toDouble(j['total_income']),
        totalExpense: _toDouble(j['total_expense']),
        expectedAmount: _toDouble(j['expected_amount']),
      );
}

/// Resumen de ventas del día (para el inicio).
class DaySummary {
  final int salesCount;
  final double salesTotal;
  final String scope; // 'own' | 'all'

  DaySummary({
    required this.salesCount,
    required this.salesTotal,
    required this.scope,
  });

  factory DaySummary.fromJson(Map<String, dynamic> j) => DaySummary(
        salesCount: (j['sales_count'] as num?)?.toInt() ?? 0,
        salesTotal: _toDouble(j['sales_total']),
        scope: (j['scope'] ?? 'own') as String,
      );
}

/// Movimiento de caja (ingreso o gasto) de la sesión abierta.
class CashMovement {
  final int id;
  final String type; // 'income' | 'expense'
  final String category; // etiqueta legible
  final double amount;
  final String? method;
  final String? description;
  final DateTime? date;

  CashMovement({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    this.method,
    this.description,
    this.date,
  });

  bool get isExpense => type == 'expense';

  factory CashMovement.fromJson(Map<String, dynamic> j) => CashMovement(
        id: j['id'] as int,
        type: (j['type'] ?? 'expense') as String,
        category: (j['category'] ?? '') as String,
        amount: _toDouble(j['amount']),
        method: j['method'] as String?,
        description: j['description'] as String?,
        date: j['date'] != null ? DateTime.tryParse(j['date'] as String) : null,
      );
}

class CashRegisterOption {
  final int id;
  final String name;
  final String? branch;
  final bool hasSession;

  CashRegisterOption({
    required this.id,
    required this.name,
    this.branch,
    required this.hasSession,
  });

  factory CashRegisterOption.fromJson(Map<String, dynamic> j) =>
      CashRegisterOption(
        id: j['id'] as int,
        name: j['name'] as String,
        branch: j['branch'] as String?,
        hasSession: (j['has_session'] as bool?) ?? false,
      );
}

class SaleItem {
  final String name;
  final double quantity;
  final double unitPrice;
  final double subtotal;

  SaleItem({
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });

  factory SaleItem.fromJson(Map<String, dynamic> j) => SaleItem(
        name: (j['name'] ?? '') as String,
        quantity: _toDouble(j['quantity']),
        unitPrice: _toDouble(j['unit_price']),
        subtotal: _toDouble(j['subtotal']),
      );
}

class Mechanic {
  final int id;
  final String name;
  Mechanic({required this.id, required this.name});
  factory Mechanic.fromJson(Map<String, dynamic> j) =>
      Mechanic(id: j['id'] as int, name: j['name'] as String);
}

class VehicleOption {
  final int id;
  final String label;
  final String? plate;
  VehicleOption({required this.id, required this.label, this.plate});
  factory VehicleOption.fromJson(Map<String, dynamic> j) => VehicleOption(
        id: j['id'] as int,
        label: (j['label'] ?? '') as String,
        plate: j['plate'] as String?,
      );
}

class WoService {
  final int id;
  final String description;
  final double price;
  final int quantity;
  final double subtotal;
  final String? mechanic;
  WoService({
    required this.id,
    required this.description,
    required this.price,
    required this.quantity,
    required this.subtotal,
    this.mechanic,
  });
  factory WoService.fromJson(Map<String, dynamic> j) => WoService(
        id: j['id'] as int,
        description: (j['description'] ?? '') as String,
        price: _toDouble(j['price']),
        quantity: (j['quantity'] as num?)?.toInt() ?? 1,
        subtotal: _toDouble(j['subtotal']),
        mechanic: j['mechanic'] as String?,
      );
}

class WoPart {
  final int id;
  final String name;
  final int quantity;
  final double unitPrice;
  final double subtotal;
  WoPart({
    required this.id,
    required this.name,
    required this.quantity,
    required this.unitPrice,
    required this.subtotal,
  });
  factory WoPart.fromJson(Map<String, dynamic> j) => WoPart(
        id: j['id'] as int,
        name: (j['name'] ?? '') as String,
        quantity: (j['quantity'] as num?)?.toInt() ?? 1,
        unitPrice: _toDouble(j['unit_price']),
        subtotal: _toDouble(j['subtotal']),
      );
}

/// Orden de trabajo. En el listado los campos de detalle vienen vacíos;
/// en el detalle traen servicios, repuestos y subtotales.
class WorkOrder {
  final int id;
  final String code;
  final String status;
  final String statusLabel;
  final String paymentStatus;
  final double total;
  final double balance;
  final double paidAmount;
  final String? client;
  final String? vehicle;
  final String? mechanic;
  final String? reportedIssue;
  final String? diagnosis;
  final int? mileage;
  final double subtotalServices;
  final double subtotalParts;
  final double discount;
  final List<WoService> services;
  final List<WoPart> parts;

  WorkOrder({
    required this.id,
    required this.code,
    required this.status,
    required this.statusLabel,
    required this.paymentStatus,
    required this.total,
    required this.balance,
    required this.paidAmount,
    this.client,
    this.vehicle,
    this.mechanic,
    this.reportedIssue,
    this.diagnosis,
    this.mileage,
    this.subtotalServices = 0,
    this.subtotalParts = 0,
    this.discount = 0,
    this.services = const [],
    this.parts = const [],
  });

  factory WorkOrder.fromJson(Map<String, dynamic> j) => WorkOrder(
        id: j['id'] as int,
        code: j['code'] as String,
        status: (j['status'] ?? '') as String,
        statusLabel: (j['status_label'] ?? '') as String,
        paymentStatus: (j['payment_status'] ?? '') as String,
        total: _toDouble(j['total']),
        balance: _toDouble(j['balance']),
        paidAmount: _toDouble(j['paid_amount']),
        client: j['client'] as String?,
        vehicle: j['vehicle'] as String?,
        mechanic: j['mechanic'] as String?,
        reportedIssue: j['reported_issue'] as String?,
        diagnosis: j['diagnosis'] as String?,
        mileage: (j['mileage'] as num?)?.toInt(),
        subtotalServices: _toDouble(j['subtotal_services']),
        subtotalParts: _toDouble(j['subtotal_parts']),
        discount: _toDouble(j['discount']),
        services: ((j['services'] as List?) ?? [])
            .map((e) => WoService.fromJson(e as Map<String, dynamic>))
            .toList(),
        parts: ((j['parts'] as List?) ?? [])
            .map((e) => WoPart.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Sale {
  final int id;
  final String code;
  final String saleType;
  final double total;
  final double paidAmount;
  final double balance;
  final String paymentStatus;
  final String? client;
  final DateTime? saleDate;
  final List<SaleItem> items;

  Sale({
    required this.id,
    required this.code,
    required this.saleType,
    required this.total,
    required this.paidAmount,
    required this.balance,
    required this.paymentStatus,
    this.client,
    this.saleDate,
    required this.items,
  });

  factory Sale.fromJson(Map<String, dynamic> j) => Sale(
        id: j['id'] as int,
        code: j['code'] as String,
        saleType: (j['sale_type'] ?? 'cash') as String,
        total: _toDouble(j['total']),
        paidAmount: _toDouble(j['paid_amount']),
        balance: _toDouble(j['balance']),
        paymentStatus: (j['payment_status'] ?? '') as String,
        client: j['client'] as String?,
        saleDate: j['sale_date'] != null
            ? DateTime.tryParse(j['sale_date'] as String)
            : null,
        items: ((j['items'] as List?) ?? [])
            .map((e) => SaleItem.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}
