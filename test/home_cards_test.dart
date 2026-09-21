import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/core/theme.dart';
import 'package:rodex_movil/features/agenda/agenda_repository.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/home/home_screen.dart';
import 'package:rodex_movil/features/pos/pos_repository.dart';
import 'package:rodex_movil/features/workshop/workshop_repository.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(Ref ref, List<String> permissions)
    : super(ApiClient(), SecureStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'VR MOTORS'),
        companies: [Company(id: 1, name: 'VR MOTORS')],
        permissions: permissions,
        planFeatures: const ['sales', 'workshop'],
      ),
    );
  }
}

Widget _app(List<String> perms) => ProviderScope(
  overrides: [
    authControllerProvider.overrideWith((ref) => _FakeAuth(ref, perms)),
    cashSessionProvider.overrideWith((ref) async => null),
    todaySummaryProvider.overrideWith(
      (ref) async => DaySummary(salesCount: 3, salesTotal: 450, scope: 'all'),
    ),
    workOrdersSummaryProvider.overrideWith(
      (ref) async =>
          WorkOrdersSummary(receivedToday: 2, active: 7, scope: 'all'),
    ),
    agendaDayProvider.overrideWith(
      (ref, date) async => AgendaDay(
        date: date,
        total: 4,
        programada: 1,
        confirmada: 2,
        completada: 1,
        appointments: const [],
      ),
    ),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: HomeScreen()),
);

void main() {
  testWidgets(
    'Ventas, OTs y Citas de hoy en la misma fila (ancho de teléfono), con sus conteos',
    (tester) async {
      // Ancho de teléfono real (360 dp): las tres deben caber sin overflow.
      tester.view.physicalSize = const Size(360, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        _app(const ['workshop.view', 'appointments.view', 'pos.access']),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('Ventas hoy'), findsOneWidget);
      expect(find.text('3 ventas'), findsOneWidget);
      expect(find.text('OTs hoy'), findsOneWidget);
      expect(find.text('recibidas · 7 act.'), findsOneWidget);
      expect(find.text('Citas hoy'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
      expect(find.text('3 pendientes'), findsOneWidget);

      // Misma fila: las tres tarjetas comparten el mismo Row padre y están
      // alineadas verticalmente.
      final row = find
          .ancestor(of: find.text('Citas hoy'), matching: find.byType(Row))
          .last;
      expect(
        find.descendant(of: row, matching: find.text('OTs hoy')),
        findsOneWidget,
      );
      expect(
        find.descendant(of: row, matching: find.text('Ventas hoy')),
        findsOneWidget,
      );
      expect(
        tester.getTopLeft(find.text('Ventas hoy')).dy,
        tester.getTopLeft(find.text('Citas hoy')).dy,
      );
    },
  );

  testWidgets('Sin appointments.view ni ventas: solo OTs (a todo el ancho)', (
    tester,
  ) async {
    await tester.pumpWidget(_app(const ['workshop.view']));
    await tester.pumpAndSettle();

    expect(find.text('OTs hoy'), findsOneWidget);
    expect(find.text('Ventas hoy'), findsNothing);
    expect(find.text('Citas hoy'), findsNothing);
  });

  testWidgets('Sin workshop.view pero con agenda: solo Citas', (tester) async {
    await tester.pumpWidget(_app(const ['appointments.view']));
    await tester.pumpAndSettle();

    expect(find.text('OTs hoy'), findsNothing);
    expect(find.text('Citas hoy'), findsOneWidget);
  });
}
