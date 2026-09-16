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
  _FakeAuth(Ref ref) : super(ApiClient(), SecureStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'VR MOTORS'),
        companies: [Company(id: 1, name: 'VR MOTORS')],
        permissions: const [
          'workshop.view',
          'workshop.create',
          'appointments.view',
          'appointments.create',
          'mechanics.view',
          'mechanics.create',
        ],
        planFeatures: const ['workshop'],
      ),
    );
  }
}

WorkOrder _wo(int i) => WorkOrder.fromJson({
  'id': i,
  'code': 'OT-0000$i',
  'status': ['recibida', 'diagnosticada', 'en_proceso', 'terminada'][i % 4],
  'status_label': 'En proceso',
  'payment_status': 'pendiente',
  'total': 350.5 * i,
  'balance': 120.0,
  'paid_amount': 0,
  'client': 'Cliente con nombre bastante largo número $i',
  'client_phone': '70000000',
  'vehicle': 'Honda CG 150 Titan · 1234-ABC',
  'mechanic': 'Pedro Mamani',
  'reception_date': '2026-09-16T09:00:00',
});

Appointment _appt(int i, String date) => Appointment.fromJson({
  'id': i,
  'date': date,
  'time': '${(8 + i).toString().padLeft(2, '0')}:00',
  'end_time': '${(9 + i).toString().padLeft(2, '0')}:00',
  'duration_minutes': 60,
  'status': ['programada', 'confirmada', 'completada'][i % 3],
  'status_label': 'Programada',
  'title': 'Cambio de aceite y revisión de frenos completa',
  'display_name': 'Juan Pérez Rodríguez',
  'display_phone': '71234567',
  'client_id': 1,
  'vehicle_label': 'Yamaha FZ 150',
  'services': [
    {'id': 1, 'name': 'Cambio de aceite'},
    {'id': 2, 'name': 'Frenos'},
  ],
});

void main() {
  testWidgets(
    'Hub Taller con datos a tamaño de teléfono: sin excepciones en los 3 tabs',
    (tester) async {
      // Teléfono real (360x640 dp): cualquier overflow o assert saldría aquí.
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final today = DateTime.now();
      String ymd(DateTime d) =>
          '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
            workOrdersProvider.overrideWith(
              (ref) async => [for (var i = 1; i <= 12; i++) _wo(i)],
            ),
            mechanicsFullProvider.overrideWith(
              (ref) async => [
                for (var i = 1; i <= 6; i++)
                  MechanicFull(
                    id: i,
                    name: 'Mecánico $i',
                    specialty: 'Motor',
                    phone: '7000000$i',
                    commissionRate: 10,
                    active: i % 2 == 0,
                  ),
              ],
            ),
            agendaDayProvider.overrideWith(
              (ref, date) async => AgendaDay(
                date: date,
                total: 5,
                programada: 2,
                confirmada: 2,
                completada: 1,
                appointments: [for (var i = 0; i < 5; i++) _appt(i, date)],
              ),
            ),
            agendaRangeProvider.overrideWith(
              (ref, key) async => [
                for (var i = 0; i < 6; i++)
                  _appt(i, ymd(today.add(Duration(days: i)))),
              ],
            ),
          ],
          child: const MaterialApp(home: WorkshopHubScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('OT-00001'), findsOneWidget);

      await tester.tap(find.text('Agenda'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Semana'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Mes'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Mecánicos'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Mecánico 1'), findsOneWidget);
    },
  );
}
