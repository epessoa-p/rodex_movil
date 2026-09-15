import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/dashboard/analytics_screen.dart';
import 'package:rodex_movil/features/dashboard/dashboard_repository.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(Ref ref) : super(ApiClient(), SecureStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'VR MOTORS'),
        companies: [Company(id: 1, name: 'VR MOTORS')],
        permissions: const ['sales-dashboard.view', 'workshop-dashboard.view'],
        planFeatures: const ['sales', 'workshop'],
      ),
    );
  }
}

/// Payload tal como lo devuelve GET /dashboard/top. El servidor ya ordena por
/// `by`; aquí simulamos ambos órdenes.
Map<String, dynamic> _payload(String by) => {
      'period': {
        'key': 'month',
        'label': 'Este mes',
        'from': '2026-09-01',
        'to': '2026-09-15'
      },
      'by': by,
      'revenue': [
        {'key': 'sales', 'label': 'Ventas', 'amount': 7500.0, 'count': 30},
        {'key': 'workshop', 'label': 'Taller', 'amount': 2500.0, 'count': 10},
      ],
      'top_products': by == 'amount'
          ? [
              {'label': 'Llanta 90/90', 'amount': 3000.0, 'qty': 5},
              {'label': 'Aceite 20W50', 'amount': 1200.0, 'qty': 40},
            ]
          : [
              {'label': 'Aceite 20W50', 'amount': 1200.0, 'qty': 40},
              {'label': 'Llanta 90/90', 'amount': 3000.0, 'qty': 5},
            ],
      'top_services': [
        {'label': 'Cambio de aceite', 'amount': 900.0, 'qty': 18},
      ],
      'top_purchases': null, // sin plan/permiso de compras
      'top_clients': [
        {'label': 'Juan Pérez', 'amount': 640.0, 'qty': 3},
      ],
    };

Widget _app() => ProviderScope(
      overrides: [
        authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
        // Series de los tabs de módulo (no se abren en este test).
        dashboardSeriesProvider.overrideWith((ref, m) async =>
            DashboardSeries(weekly: [], monthly: [], weekCompare: [])),
        dashboardTopProvider.overrideWith((ref, key) async =>
            DashboardTop.fromJson(_payload(key.split('|')[1]))),
      ],
      child: const MaterialApp(home: AnalyticsScreen()),
    );

void main() {
  testWidgets('Tab Top: donut con %, rankings y toggle Monto/Cantidad',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    // Tabs de módulo + "Top" al final.
    expect(find.text('Ventas'), findsWidgets);
    expect(find.text('Taller'), findsWidgets);
    expect(find.text('Top'), findsOneWidget);

    await tester.tap(find.text('Top'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Donut + leyenda con porcentaje (7500 / 10000 = 75 %).
    expect(find.text('Ingresos por origen'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('25%'), findsOneWidget);

    // Rankings: compras viene null → no se pinta.
    expect(find.text('Top repuestos'), findsOneWidget);
    expect(find.text('Top servicios'), findsOneWidget);
    expect(find.text('Top clientes'), findsOneWidget);
    expect(find.text('Top compras'), findsNothing);

    // Por monto: la llanta va primero y la cantidad se ve en pequeño ("×5 u.").
    expect(find.text('×5 u.'), findsOneWidget);
    final llantaY = tester.getTopLeft(find.text('Llanta 90/90')).dy;
    final aceiteY = tester.getTopLeft(find.text('Aceite 20W50')).dy;
    expect(llantaY, lessThan(aceiteY));

    // Cambio a Cantidad: el aceite (40 u.) pasa arriba y el % del donut usa ops.
    await tester.tap(find.text('Cantidad'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('40 u.'), findsOneWidget);
    expect(tester.getTopLeft(find.text('Aceite 20W50')).dy,
        lessThan(tester.getTopLeft(find.text('Llanta 90/90')).dy));
    // 30 / 40 ops = 75 % (mismo reparto en este payload), sigue habiendo %.
    expect(find.text('75%'), findsOneWidget);

    // Pie del período.
    expect(find.text('Período: 01/09/2026 — 15/09/2026'), findsOneWidget);
  });
}
