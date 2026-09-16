import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/features/agenda/agenda_repository.dart';
import 'package:rodex_movil/features/agenda/appointment_form_screen.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';

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

/// Repositorio falso: captura el body enviado al crear.
class _FakeAgenda extends AgendaRepository {
  Map<String, dynamic>? sent;
  final createdServices = <String>[];
  _FakeAgenda() : super(ApiClient());

  @override
  Future<IdName> createService({
    required String name,
    required double price,
  }) async {
    createdServices.add('$name|$price');
    return IdName(id: 99, name: name);
  }

  @override
  Future<Appointment> create(Map<String, dynamic> body) async {
    sent = body;
    return Appointment.fromJson({
      'id': 1,
      'date': '2026-09-15',
      'time': '09:00',
      'duration_minutes': 60,
      'status': 'programada',
      'status_label': 'Programada',
      'display_name': 'X',
      'services': [],
    });
  }
}

Widget _app(
  _FakeAgenda repo, {
  List<String> perms = const ['services.create'],
}) => ProviderScope(
  overrides: [
    authControllerProvider.overrideWith((ref) => _FakeAuth(ref, perms)),
    agendaRepositoryProvider.overrideWithValue(repo),
    appointmentMetaProvider.overrideWith(
      (ref) async => AppointmentMeta(
        services: [
          ServiceOption(id: 1, name: 'Cambio de aceite', price: 50),
          ServiceOption(id: 2, name: 'Frenos', price: 50),
          ServiceOption(id: 3, name: 'Alineación', price: 50),
        ],
        mechanics: [],
      ),
    ),
  ],
  child: MaterialApp(home: AppointmentFormScreen(date: DateTime(2026, 9, 15))),
);

void main() {
  testWidgets(
    'Varios servicios: hoja con buscador, chips y service_ids en el body',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeAgenda();
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      // Modo rápido con nombre + teléfono (el backend registra al cliente).
      await tester.tap(find.text('Rápido'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre del cliente *'),
        'Luis Paz',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Teléfono (opcional)'),
        '71234567',
      );

      // Abrir la hoja de servicios: no debe lanzar excepción (foco diferido).
      await tester.tap(find.text('Agregar servicio'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Buscar servicio…'), findsOneWidget);

      // Buscar y marcar dos.
      await tester.enterText(find.byType(TextField).last, 'fre');
      await tester.pumpAndSettle();
      expect(find.text('Frenos'), findsOneWidget);
      expect(find.text('Alineación'), findsNothing);
      await tester.tap(find.text('Frenos'));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cambio de aceite'));
      await tester.pumpAndSettle();
      expect(find.text('Listo (2)'), findsOneWidget);
      await tester.tap(find.text('Listo (2)'));
      await tester.pumpAndSettle();

      // Chips en el formulario y motivo autocompletado.
      expect(find.byType(InputChip), findsNWidgets(2));
      expect(find.text('Cambio de aceite, Frenos'), findsOneWidget);

      // Quitar uno con la × del chip.
      tester
          .widget<InputChip>(find.widgetWithText(InputChip, 'Frenos'))
          .onDeleted!();
      await tester.pumpAndSettle();
      expect(find.byType(InputChip), findsOneWidget);

      await tester.tap(find.text('Guardar cita'));
      await tester.pumpAndSettle();

      final body = repo.sent!;
      expect(body['service_ids'], [1]);
      expect(body['customer_name'], 'LUIS PAZ'); // mayúsculas automáticas
      expect(body['customer_phone'], '71234567');
      expect(body.containsKey('service_id'), isFalse);

      // Toast "Cita agendada." arriba; se drena su temporizador.
      expect(find.text('Cita agendada.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    },
  );

  testWidgets(
    'Crear servicio desde el selector: queda marcado y viaja en service_ids',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeAgenda();
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Agregar servicio'));
      await tester.pumpAndSettle();

      // Buscar algo que no existe → botón "Crear «…»" con el texto prellenado.
      await tester.enterText(find.byType(TextField).last, 'Pintura');
      await tester.pumpAndSettle();
      expect(find.text('Sin resultados.'), findsOneWidget);
      await tester.tap(find.text('Crear «Pintura»'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Diálogo: nombre prellenado; sin precio → aviso y sigue abierto.
      expect(find.widgetWithText(TextField, 'Nombre *'), findsOneWidget);
      await tester.tap(find.text('Crear'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Precio inválido'), findsOneWidget);
      expect(repo.createdServices, isEmpty);

      await tester.enterText(find.widgetWithText(TextField, 'Precio *'), '80');
      await tester.tap(find.text('Crear'));
      await tester.pumpAndSettle();

      expect(repo.createdServices, ['Pintura|80.0']);
      // Aparece en la lista, marcado, y el buscador se limpió.
      expect(find.text('Pintura'), findsOneWidget);
      expect(find.text('Listo (1)'), findsOneWidget);
      await tester.tap(find.text('Listo (1)'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(InputChip, 'Pintura'), findsOneWidget);

      // Modo rápido para poder guardar sin cliente registrado.
      await tester.tap(find.text('Rápido'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre del cliente *'),
        'Ana',
      );
      await tester.tap(find.text('Guardar cita'));
      await tester.pumpAndSettle();
      expect(repo.sent!['service_ids'], [99]);

      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    },
  );

  testWidgets('Sin services.create no se ofrece crear', (tester) async {
    final repo = _FakeAgenda();
    await tester.pumpWidget(_app(repo, perms: const []));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Agregar servicio'));
    await tester.pumpAndSettle();
    expect(find.text('Nuevo servicio'), findsNothing);

    await tester.enterText(find.byType(TextField).last, 'Pintura');
    await tester.pumpAndSettle();
    expect(find.text('Sin resultados.'), findsOneWidget);
    expect(find.textContaining('Crear «'), findsNothing);
  });
}
