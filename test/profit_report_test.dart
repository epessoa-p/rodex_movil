import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/theme.dart';
import 'package:rodex_movil/features/reports/profit_report_repository.dart';
import 'package:rodex_movil/features/reports/profit_report_screen.dart';
import 'package:rodex_movil/features/reports/report_period.dart';

/// Respuesta de ejemplo (mismos números que el script del backend).
Map<String, dynamic> _json(ProfitQuery q) {
  final sales = q.scope != ProfitScope.workshop;
  final shop = q.scope != ProfitScope.sales;
  final quick = sales && q.mergeQuick ? 40.0 : 0.0;
  final revenue = (sales ? 135.0 : 0) + (shop ? 370.0 : 0) + quick;
  final cost = (sales ? 90.0 : 0) + (shop ? 60.0 : 0);
  final commission = shop ? 32.0 : 0.0;
  final profit = revenue - cost - commission;
  return {
    'from': '2026-10-09',
    'to': '2026-10-09',
    'totals': {
      'revenue': revenue,
      'cost': cost,
      'commission': commission,
      'profit': profit,
      'margin': revenue > 0 ? profit / revenue * 100 : 0,
    },
    'sales': {
      'enabled': sales,
      'revenue': sales ? 135 + quick : 0,
      'cost': sales ? 90 : 0,
      'profit': sales ? 45 + quick : 0,
      'margin': 33.3,
      'count': 2,
      'returns_revenue': 90,
    },
    'workshop': {
      'enabled': shop,
      'labor': 280,
      'parts': 90,
      'parts_cost': 60,
      'commission_paid': 12,
      'commission_pending': 20,
      'profit': 278,
      'margin': 75.1,
      'count': 2,
    },
    'quick': {
      'revenue': sales ? 40 : 0,
      'count': sales ? 1 : 0,
      'merged': q.mergeQuick,
    },
    'by_day': [
      {'date': '2026-10-08', 'revenue': 225, 'cost': 150, 'profit': 75},
      {'date': '2026-10-09', 'revenue': 180, 'cost': 20, 'profit': 160},
    ],
    'top_products': [
      {
        'name': 'FILTRO DE ACEITE PREMIUM PARA MOTO 150CC',
        'quantity': 2,
        'revenue': 180,
        'cost': 120,
        'profit': 60,
        'margin': 33.3,
      },
    ],
    'low_margin': [
      {
        'name': 'BUJIA',
        'quantity': 1,
        'revenue': 45,
        'cost': 44,
        'profit': 1,
        'margin': 2.2,
      },
    ],
    'estimated_lines': 1,
    'transactions': [
      for (var i = 25; i >= 1; i--)
        {
          'type': i.isEven ? 'ot' : 'sale',
          'id': i,
          'code': 'VEN-${i.toString().padLeft(3, '0')}',
          'date': '2026-10-09 10:${i.toString().padLeft(2, '0')}',
          'client': i == 25 ? null : 'CLIENTE CON UN NOMBRE MUY LARGO $i',
          'revenue': 100.0 * i,
          'cost': 60.0 * i,
          'profit': 40.0 * i,
          'margin': 40,
          'quick': i == 3 ? 15 : 0,
          'estimated': i == 1,
        },
    ],
    'transactions_total': 40,
    'branches': [
      {'id': 1, 'name': 'Central'},
      {'id': 2, 'name': 'Norte'},
    ],
  };
}

void main() {
  final queries = <ProfitQuery>[];

  Future<void> pump(WidgetTester t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    queries.clear();
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          profitReportProvider.overrideWith((ref, q) async {
            queries.add(q);
            return ProfitReport.fromJson(_json(q));
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ProfitReportScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> scrollTo(WidgetTester t, Finder f) => t.scrollUntilVisible(
    f,
    150,
    scrollable: find
        .descendant(
          of: find.byType(ListView).last,
          matching: find.byType(Scrollable),
        )
        .first,
  );

  String profitText(WidgetTester t) =>
      t.widget<Text>(find.byKey(const Key('profit_total'))).data!;

  testWidgets('abre en Hoy con ventas y taller; sin overflow a 360 dp', (
    t,
  ) async {
    await pump(t);
    expect(queries.last.period.preset, ReportPreset.today);
    expect(queries.last.scope, ProfitScope.all);
    expect(profitText(t), contains('323.00'));
    expect(find.textContaining('Hoy,'), findsOneWidget);
    expect(find.textContaining('ganancia estimada'), findsOneWidget);
    await scrollTo(t, find.textContaining('Aparte:'));
    expect(find.textContaining('Aparte:'), findsOneWidget);

    // Bajar por todo el reporte: secciones y productos sin desbordes.
    await t.drag(find.byType(ListView).last, const Offset(0, -1600));
    await t.pumpAndSettle();
    expect(find.text('Productos'), findsOneWidget);
    await t.tap(find.text('Margen bajo'));
    await t.pumpAndSettle();
    expect(find.text('BUJIA'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('unir ventas rápidas suma su ingreso y avisa', (t) async {
    await pump(t);
    await t.tap(find.byKey(const Key('merge_quick')));
    await t.pumpAndSettle();
    expect(queries.last.mergeQuick, isTrue);
    expect(profitText(t), contains('363.00'));
    await scrollTo(t, find.textContaining('más alto de lo real'));
    expect(find.textContaining('más alto de lo real'), findsOneWidget);
  });

  testWidgets('solo taller oculta ventas y el switch', (t) async {
    await pump(t);
    await t.tap(find.text('Taller').first);
    await t.pumpAndSettle();
    expect(queries.last.scope, ProfitScope.workshop);
    expect(find.byKey(const Key('merge_quick')), findsNothing);
    expect(profitText(t), contains('278.00'));
    expect(find.text('Comisión mecánicos (por pagar)'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('listado de ventas con su ganancia y scroll propio', (t) async {
    await pump(t);
    final list = find.byKey(const Key('profit_transactions'));
    await t.scrollUntilVisible(
      list,
      300,
      scrollable: find
          .descendant(
            of: find.byType(ListView).first,
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await t.pumpAndSettle();
    expect(find.text('Las 25 más recientes de 40'), findsOneWidget);
    expect(find.text('VEN-025'), findsOneWidget);
    expect(find.text('VEN-001'), findsNothing);
    // El recuadro se desplaza por dentro hasta la venta más antigua.
    await t.scrollUntilVisible(
      find.text('VEN-001'),
      200,
      scrollable: find
          .descendant(of: list, matching: find.byType(Scrollable))
          .first,
    );
    expect(find.text('VEN-001'), findsOneWidget);
    expect(find.text('estimada'), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  test('parámetros enviados a la API', () {
    final q = ProfitQuery(
      period: ReportPeriod.of(ReportPreset.today, now: DateTime(2026, 10, 9)),
      branchId: 2,
      scope: ProfitScope.sales,
      mergeQuick: true,
    );
    expect(q.params, {
      'from': '2026-10-09',
      'to': '2026-10-09',
      'branch_id': 2,
      'scope': 'sales',
      'merge_quick': 1,
    });
  });
}
