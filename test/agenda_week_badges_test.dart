import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/core/theme.dart';
import 'package:rodex_movil/features/agenda/agenda_repository.dart';
import 'package:rodex_movil/features/agenda/agenda_screen.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(Ref ref) : super(ApiClient(), SecureStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'VR MOTORS'),
        companies: [Company(id: 1, name: 'VR MOTORS')],
        permissions: const ['appointments.view'],
        planFeatures: const ['workshop'],
      ),
    );
  }
}

String _ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

Appointment _appt(int id, String date, String time, String status) =>
    Appointment.fromJson({
      'id': id,
      'date': date,
      'time': time,
      'duration_minutes': 60,
      'status': status,
      'status_label': status,
      'display_name': 'Cliente $id',
      'services': [],
    });

void main() {
  testWidgets(
    'Tira semanal: numerito por día; rojo si hay cita vencida sin completar',
    (tester) async {
      final today = DateTime.now();
      final todayStr = _ymd(today);
      // Un día de la misma semana distinto de hoy (mañana o ayer si hoy es domingo).
      final other = today.weekday == 7
          ? today.subtract(const Duration(days: 1))
          : today.add(const Duration(days: 1));
      final otherStr = _ymd(other);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
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
            agendaRangeProvider.overrideWith(
              (ref, key) async => [
                // Hoy: una vencida (00:00, programada) + una completada → 2, rojo.
                _appt(1, todayStr, '00:00', 'programada'),
                _appt(2, todayStr, '23:59', 'completada'),
                // Otro día: 3 citas, ninguna vencida (mañana) o todas completadas.
                _appt(3, otherStr, '09:00', 'completada'),
                _appt(4, otherStr, '10:00', 'completada'),
                _appt(5, otherStr, '11:00', 'completada'),
              ],
            ),
          ],
          child: MaterialApp(theme: AppTheme.light(), home: AgendaScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Los numeritos existen.
      expect(find.text('2'), findsWidgets);
      expect(find.text('3'), findsWidgets);

      // El de hoy (2) va sobre fondo rojo; el otro (3) no. Se miran TODOS los
      // textos "2"/"3": la tira también muestra el número del día del mes, que
      // los días 2 y 3 coincide con los numeritos (el test fallaba según la fecha).
      Iterable<Color?> bgsOf(String n) => find.text(n).evaluate().map((e) {
        final d = e.findAncestorWidgetOfExactType<Container>()?.decoration;
        return d is BoxDecoration ? d.color : null;
      });

      expect(bgsOf('2'), contains(Colors.red));
      expect(bgsOf('3'), isNot(contains(Colors.red)));
    },
  );
}
