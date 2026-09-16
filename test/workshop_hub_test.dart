import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/features/agenda/agenda_repository.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/workshop/workshop_hub_screen.dart';
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
        planFeatures: const ['workshop'],
      ),
    );
  }
}

Widget _app(
  List<String> perms, {
  WorkshopTab initialTab = WorkshopTab.orders,
}) => ProviderScope(
  overrides: [
    authControllerProvider.overrideWith((ref) => _FakeAuth(ref, perms)),
    workOrdersProvider.overrideWith((ref) async => <WorkOrder>[]),
    mechanicsFullProvider.overrideWith(
      (ref) async => [
        MechanicFull(
          id: 1,
          name: 'Pedro Mamani',
          commissionRate: 0,
          active: true,
        ),
      ],
    ),
    agendaDayProvider.overrideWith(
      (ref, date) async => AgendaDay(
        date: date,
        total: 0,
        programada: 0,
        confirmada: 0,
        completada: 0,
        appointments: const [],
      ),
    ),
    agendaRangeProvider.overrideWith((ref, key) async => <Appointment>[]),
  ],
  child: MaterialApp(home: WorkshopHubScreen(initialTab: initialTab)),
);

void main() {
  testWidgets('Con los 3 permisos: 3 tabs, arranca en OTs y cambia a Agenda', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const ['workshop.view', 'appointments.view', 'mechanics.view']),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(find.text('Taller'), findsOneWidget); // título del hub
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('OTs'), findsOneWidget);
    expect(find.text('Agenda'), findsOneWidget);
    expect(find.text('Mecánicos'), findsOneWidget);
    expect(find.text('Nueva OT'), findsOneWidget);

    await tester.tap(find.text('Agenda'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Conmutador Día/Semana/Mes dentro del tab (no hay AppBar propio).
    expect(find.text('Semana'), findsOneWidget);
    expect(find.byType(AppBar), findsOneWidget);
  });

  testWidgets('Ruta /mechanics abre el hub en el tab Mecánicos', (
    tester,
  ) async {
    await tester.pumpWidget(
      _app(const [
        'workshop.view',
        'appointments.view',
        'mechanics.view',
      ], initialTab: WorkshopTab.mechanics),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pedro Mamani'), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 2);
  });

  testWidgets('Un solo permiso: un tab y SIN barra inferior', (tester) async {
    await tester.pumpWidget(_app(const ['workshop.view']));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Nueva OT'), findsOneWidget);
    expect(find.text('Mecánicos'), findsNothing);
  });
}
