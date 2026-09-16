import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/features/agenda/agenda_repository.dart';
import 'package:rodex_movil/features/agenda/appointment_form_screen.dart';

/// Repositorio falso: captura el body enviado al crear.
class _FakeAgenda extends AgendaRepository {
  Map<String, dynamic>? sent;
  _FakeAgenda() : super(ApiClient());

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

Widget _app(_FakeAgenda repo) => ProviderScope(
  overrides: [
    agendaRepositoryProvider.overrideWithValue(repo),
    appointmentMetaProvider.overrideWith(
      (ref) async => AppointmentMeta(
        services: [
          IdName(id: 1, name: 'Cambio de aceite'),
          IdName(id: 2, name: 'Frenos'),
          IdName(id: 3, name: 'Alineación'),
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
      expect(body['customer_name'], 'Luis Paz');
      expect(body['customer_phone'], '71234567');
      expect(body.containsKey('service_id'), isFalse);

      // Toast "Cita agendada." arriba; se drena su temporizador.
      expect(find.text('Cita agendada.'), findsOneWidget);
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
    },
  );
}
