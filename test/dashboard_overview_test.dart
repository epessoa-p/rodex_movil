import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/features/dashboard/dashboard_screen.dart';
import 'package:rodex_movil/features/dashboard/overview_repository.dart';

/// Payload tal como lo devuelve GET /dashboard/overview.
const _full = {
  'date': '2026-09-11',
  'sales': {'count': 5, 'total': 1250.0},
  'workshop': {
    'received_today': 3,
    'active': 12,
    'vehicles_in_shop': 11,
    'by_status': {'recibida': 4, 'diagnosticada': 2, 'en_proceso': 5, 'terminada': 1},
    'appointments': {
      'total': 4,
      'pending': 2,
      'next': {'id': 9, 'time': '15:30', 'client': 'Juan Pérez', 'title': 'Cambio de aceite'},
    },
    'top_services': [
      {'label': 'Cambio de aceite', 'amount': 1200.0, 'count': 8},
      {'label': 'Frenos', 'amount': 600.0, 'count': 3},
    ],
    'recent': [
      {
        'id': 1, 'code': 'OT-00042', 'status': 'en_proceso',
        'status_label': 'En proceso', 'payment_status': 'pendiente',
        'total': 350.0, 'balance': 350.0, 'client': 'María López',
        'vehicle': 'Honda CG 150 · 1234-ABC', 'reception_date': '2026-09-11',
      },
    ],
  },
  'stock': {'in_stock': 590, 'low_stock': 12},
};

Widget _app(Map<String, dynamic> payload) => ProviderScope(
      overrides: [
        dashboardOverviewProvider.overrideWith(
            (ref) async => DashboardOverview.fromJson(payload)),
      ],
      child: const MaterialApp(home: DashboardScreen()),
    );

void main() {
  testWidgets('Dashboard completo: KPIs, estados, cita, servicios y OTs',
      (tester) async {
    // Superficie alta para que el ListView construya todos los bloques.
    tester.view.physicalSize = const Size(1080, 4000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_full));
    await tester.pumpAndSettle();

    // KPIs
    expect(find.text('Ventas hoy'), findsOneWidget);
    expect(find.text('5 ventas'), findsOneWidget);
    expect(find.text('OTs hoy'), findsOneWidget);
    expect(find.text('12 activas'), findsOneWidget);
    expect(find.text('Motos en taller'), findsOneWidget);
    expect(find.text('11'), findsOneWidget);
    expect(find.text('Citas hoy'), findsOneWidget);
    expect(find.text('Repuestos en stock'), findsOneWidget);
    expect(find.text('12 en stock bajo'), findsOneWidget);

    // Bloques de taller
    expect(find.text('OTs en taller por estado'), findsOneWidget);
    expect(find.text('Próxima cita'), findsOneWidget);
    expect(find.text('15:30'), findsOneWidget);
    expect(find.text('Ventas por servicio'), findsOneWidget);
    expect(find.text('Cambio de aceite'), findsOneWidget);
    expect(find.text('×8'), findsOneWidget);
    expect(find.text('OTs recientes'), findsOneWidget);
    expect(find.text('OT-00042'), findsOneWidget);
  });

  testWidgets('Sin sección de taller (plan/permiso): solo ventas y stock',
      (tester) async {
    final payload = Map<String, dynamic>.from(_full)..['workshop'] = null;
    await tester.pumpWidget(_app(payload));
    await tester.pumpAndSettle();

    expect(find.text('Ventas hoy'), findsOneWidget);
    expect(find.text('Repuestos en stock'), findsOneWidget);
    expect(find.text('OTs hoy'), findsNothing);
    expect(find.text('OTs en taller por estado'), findsNothing);
    expect(find.text('Ventas por servicio'), findsNothing);
    expect(find.text('OTs recientes'), findsNothing);
  });

  testWidgets('Sin ninguna sección: mensaje de vacío', (tester) async {
    await tester.pumpWidget(_app(const {'date': '2026-09-11'}));
    await tester.pumpAndSettle();

    expect(find.textContaining('No hay indicadores'), findsOneWidget);
  });
}
