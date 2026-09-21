import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/core/theme.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/reports/finance_report_repository.dart';
import 'package:rodex_movil/features/reports/finance_report_screen.dart';
import 'package:rodex_movil/features/reports/income_statement_repository.dart';
import 'package:rodex_movil/features/reports/inventory_report_repository.dart';
import 'package:rodex_movil/features/reports/inventory_report_screen.dart';
import 'package:rodex_movil/features/reports/report_period.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(Ref ref) : super(ApiClient(), SecureStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'VR MOTORS'),
        companies: [Company(id: 1, name: 'VR MOTORS')],
        permissions: const [
          'income-statement.view',
          'cash-registers.view',
          'products.view',
        ],
        planFeatures: const ['cash', 'inventory', 'sales'],
      ),
    );
  }
}

class _FakeFinance extends FinanceReportRepository {
  _FakeFinance() : super(ApiClient());
  final calls = <Map<String, dynamic>>[];

  @override
  Future<CashReport> cash(ReportPeriod period, {int? branchId}) async {
    calls.add({...period.query, 'branch_id': branchId});
    return CashReport.fromJson({
      'from': '2026-09-01',
      'to': '2026-09-21',
      'summary': {'income': 1500, 'expense': 400, 'balance': 1100},
      'by_category': [
        {'category': 'sale', 'label': 'Venta', 'type': 'income', 'amount': 1500},
        {
          'category': 'expense_operational',
          'label': 'Gasto operativo',
          'type': 'expense',
          'amount': 400,
        },
      ],
      'movements': [
        {
          'id': 1,
          'date': '2026-09-21T10:00:00',
          'type': 'income',
          'category': 'Venta',
          'description': 'Venta V-00001 — ANA ROJAS',
          'amount': 1500,
          'method': 'efectivo',
          'register': 'CAJA 1',
          'branch': 'CENTRO',
        },
        {
          'id': 2,
          'date': '2026-09-20T15:30:00',
          'type': 'expense',
          'category': 'Gasto operativo',
          'description': 'LUZ',
          'amount': 400,
          'method': 'efectivo',
          'register': 'CAJA 1',
          'branch': 'CENTRO',
        },
      ],
      'truncated': false,
      'total_count': 2,
      'closures': [
        {
          'id': 7,
          'status': 'closed',
          'register': 'CAJA 1',
          'branch': 'CENTRO',
          'opened_at': '2026-09-20T08:00:00',
          'closed_at': '2026-09-20T19:00:00',
          'opened_by': 'Luis',
          'closed_by': 'Luis',
          'opening_amount': 200,
          'income': 1500,
          'expense': 400,
          'expected_amount': 1300,
          'closing_amount': 1250,
          'difference': -50,
        },
      ],
      'branches': [
        {'id': 1, 'name': 'CENTRO'},
        {'id': 2, 'name': 'NORTE'},
      ],
    });
  }
}

class _FakeInventory extends InventoryReportRepository {
  _FakeInventory() : super(ApiClient());
  final calls = <int?>[];

  @override
  Future<InventoryReport> get({int? warehouseId}) async {
    calls.add(warehouseId);
    return InventoryReport.fromJson({
      'product_count': 639,
      'total_units': 3772,
      'value_cost': 70971.30,
      'value_price': 102000.50,
      'potential_profit': 31029.20,
      'by_category': [
        {
          'name': 'LUBRICANTES',
          'products': 3,
          'units': 120,
          'value_cost': 3000,
          'value_price': 4500,
        },
      ],
      'low_stock': [
        {
          'id': 1,
          'name': 'BUJÍA CR7HSA',
          'sku': 'ENC-001',
          'stock': 2,
          'min_stock': 5,
          'unit': 'Unidad',
        },
      ],
      'warehouse_id': warehouseId,
      'warehouses': [
        {'id': 1, 'name': 'ALM CENTRO'},
        {'id': 2, 'name': 'ALM NORTE'},
      ],
    });
  }
}

void main() {
  testWidgets('Finanzas: tabs con período compartido, movimientos y cierres', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final fin = _FakeFinance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
          financeReportRepositoryProvider.overrideWithValue(fin),
          incomeStatementProvider.overrideWith(
            (ref, key) async => IncomeStatement.fromJson({
              'from': '2026-09-01',
              'to': '2026-09-21',
              'income': [],
              'expense': [],
              'total_income': 0,
              'total_expense': 0,
              'net': 0,
            }),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const FinanceReportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Finanzas'), findsOneWidget);
    expect(find.text('Resultado del período'), findsOneWidget);

    // Movimientos: KPIs, categorías y lista agrupada por día.
    await tester.tap(find.text('Movimientos'));
    await tester.pumpAndSettle();
    expect(find.text('Bs 1,500.00'), findsWidgets);
    expect(find.text('Venta V-00001 — ANA ROJAS'), findsOneWidget);
    expect(find.text('Gasto operativo'), findsWidgets);
    expect(fin.calls.last['from'], '2026-09-01');

    // Filtro sucursal (chips desplazables) → vuelve a pedir con branch_id.
    await tester.drag(
      find.ancestor(
        of: find.text('Egresos').last,
        matching: find.byType(SingleChildScrollView),
      ),
      const Offset(-600, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('NORTE'));
    await tester.pumpAndSettle();
    expect(fin.calls.last['branch_id'], 2);

    // Cierres: diferencia negativa en rojo como "Faltante".
    await tester.tap(find.text('Cierres'));
    await tester.pumpAndSettle();
    expect(find.text('Cerrada'), findsOneWidget);
    expect(find.text('Faltante Bs 50.00'), findsOneWidget);

    // Cambiar el período afecta a todos los tabs.
    await tester.tap(find.text('Semana ant.'));
    await tester.pumpAndSettle();
    expect(fin.calls.last.containsKey('from'), isTrue);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Inventario: KPIs, almacén y stock bajo', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final inv = _FakeInventory();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
          inventoryReportRepositoryProvider.overrideWithValue(inv),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const InventoryReportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('639'), findsOneWidget);
    expect(find.text('Bs 102,000.50'), findsOneWidget);
    expect(find.text('Bs 31,029.20'), findsOneWidget);
    expect(inv.calls, [null]);

    await tester.drag(
      find.ancestor(
        of: find.text('ALM NORTE'),
        matching: find.byType(SingleChildScrollView),
      ),
      const Offset(-500, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('ALM NORTE'));
    await tester.pumpAndSettle();
    expect(inv.calls.last, 2);

    await tester.scrollUntilVisible(
      find.text('BUJÍA CR7HSA'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('BUJÍA CR7HSA'), findsOneWidget);
    expect(find.text('2 / mín. 5 Unidad'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
