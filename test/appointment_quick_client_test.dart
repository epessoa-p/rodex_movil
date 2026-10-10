import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/core/theme.dart';
import 'package:rodex_movil/features/agenda/agenda_repository.dart';
import 'package:rodex_movil/features/agenda/appointment_durations.dart';
import 'package:rodex_movil/features/agenda/appointment_form_screen.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(Ref ref) : super(ApiClient(), SecureStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'TALLER'),
        companies: [Company(id: 1, name: 'TALLER')],
        permissions: const ['appointments.create'],
        planFeatures: const ['workshop'],
      ),
    );
  }
}

/// Repositorio falso: el teléfono 70012345 ya es de CLIENTE1.
class _FakeAgenda extends AgendaRepository {
  Map<String, dynamic>? sent;
  _FakeAgenda() : super(ApiClient());

  @override
  Future<IdName?> clientByPhone(String phone) async =>
      phone.replaceAll(RegExp(r'\D'), '') == '70012345'
      ? IdName(id: 9, name: 'CLIENTE1')
      : null;

  Map<String, dynamic> _appt(Map<String, dynamic> body) => {
    'id': 1,
    'date': '2026-10-10',
    'time': '09:00',
    'duration_minutes': body['duration_minutes'] ?? 60,
    'status': 'programada',
    'status_label': 'Programada',
    'display_name': 'X',
    'services': [],
  };

  @override
  Future<Appointment> create(Map<String, dynamic> body) async {
    sent = body;
    return Appointment.fromJson(_appt(body));
  }

  @override
  Future<Appointment> update(int id, Map<String, dynamic> body) async {
    sent = body;
    return Appointment.fromJson(_appt(body));
  }
}

Widget _app(_FakeAgenda repo, {Appointment? edit}) => ProviderScope(
  overrides: [
    authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
    agendaRepositoryProvider.overrideWithValue(repo),
    appointmentMetaProvider.overrideWith(
      (ref) async => AppointmentMeta(services: [], mechanics: []),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: AppointmentFormScreen(date: DateTime(2026, 10, 10), edit: edit),
  ),
);

Future<_FakeAgenda> _pump(WidgetTester t, {Appointment? edit}) async {
  t.view.physicalSize = const Size(360, 640);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final repo = _FakeAgenda();
  await t.pumpWidget(_app(repo, edit: edit));
  await t.pumpAndSettle();
  return repo;
}

Future<void> _quick(WidgetTester t, String name, String phone) async {
  await t.tap(find.text('Rápido'));
  await t.pumpAndSettle();
  await t.enterText(
    find.widgetWithText(TextField, 'Nombre del cliente *'),
    name,
  );
  await t.enterText(find.widgetWithText(TextField, 'Teléfono *'), phone);
}

Future<void> _save(WidgetTester t) async {
  final btn = find.text('Guardar cita');
  await t.scrollUntilVisible(
    btn,
    200,
    scrollable: find
        .descendant(
          of: find.byType(ListView).first,
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await t.pumpAndSettle();
  await t.tap(btn);
  await t.pumpAndSettle();
}

/// Deja que el aviso (AppToast) se cierre solo.
Future<void> _settleToast(WidgetTester t) async {
  await t.pump(const Duration(seconds: 10));
  await t.pumpAndSettle();
}

void main() {
  testWidgets('rápido sin teléfono: no guarda', (t) async {
    final repo = await _pump(t);
    await _quick(t, 'JUAN', '');
    await _save(t);
    expect(repo.sent, isNull);
    expect(find.text('Escribe el teléfono del cliente.'), findsOneWidget);
    await _settleToast(t);
  });

  testWidgets('teléfono de otro cliente: "Registrar como nuevo"', (t) async {
    final repo = await _pump(t);
    await _quick(t, 'JUAN', '700-12345');
    await _save(t);
    expect(find.text('Teléfono ya registrado'), findsOneWidget);
    expect(find.textContaining('CLIENTE1', findRichText: true), findsWidgets);
    expect(repo.sent, isNull, reason: 'no guarda hasta elegir');
    expect(t.takeException(), isNull);

    await t.tap(find.byKey(const Key('register_new_client')));
    await t.pumpAndSettle();
    expect(repo.sent!['customer_name'], 'JUAN');
    expect(repo.sent!['customer_phone'], '700-12345');
    expect(repo.sent!['new_client'], isTrue);
    expect(repo.sent!.containsKey('client_id'), isFalse);
    await _settleToast(t);
  });

  testWidgets('teléfono de otro cliente: "Usar CLIENTE1"', (t) async {
    final repo = await _pump(t);
    await _quick(t, 'JUAN', '70012345');
    await _save(t);
    await t.tap(find.byKey(const Key('use_existing_client')));
    await t.pumpAndSettle();
    expect(repo.sent!['client_id'], 9);
    expect(repo.sent!.containsKey('customer_name'), isFalse);
    await _settleToast(t);
  });

  testWidgets('mismo nombre o teléfono nuevo: guarda directo', (t) async {
    final repo = await _pump(t);
    await _quick(t, 'cliente1', '70012345');
    await _save(t);
    expect(find.text('Teléfono ya registrado'), findsNothing);
    // El nombre se escribe en mayúsculas.
    expect(repo.sent!['customer_name'], 'CLIENTE1');
    await _settleToast(t);
  });

  testWidgets('duración de 2 días y edición con duración fuera de la lista', (
    t,
  ) async {
    final edit = Appointment.fromJson({
      'id': 5,
      'date': '2026-10-10',
      'time': '09:00',
      'duration_minutes': 1680, // 1 día 4 h: no está en la lista
      'status': 'programada',
      'status_label': 'Programada',
      'display_name': 'MARIA',
      'client_id': 3,
      'services': [],
    });
    final repo = await _pump(t, edit: edit);
    expect(find.text('1 día 4 h'), findsOneWidget);
    expect(t.takeException(), isNull);

    final dropdown = find.byType(DropdownButtonFormField<int>).last;
    await t.ensureVisible(dropdown);
    await t.pumpAndSettle();
    await t.tap(dropdown);
    await t.pumpAndSettle();
    await t.tap(find.text('2 días').last);
    await t.pumpAndSettle();
    await _save(t);
    expect(repo.sent!['duration_minutes'], 2880);
    await _settleToast(t);
  });

  test('etiquetas de duración y fin de citas largas', () {
    expect(formatDuration(90), '1 h 30 min');
    expect(formatDuration(2880), '2 días');
    expect(formatDuration(1680), '1 día 4 h');
    expect(appointmentDurations.keys.last, 7200);
    expect(multiDayEnd('2026-10-10', '09:00', 60), isNull);
    expect(multiDayEnd('2026-10-10', '09:00', 2880), 'hasta lun 12/10 09:00');
  });
}
