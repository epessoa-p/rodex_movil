import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/features/agenda/agenda_repository.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/pos/pos_repository.dart';
import 'package:rodex_movil/features/workshop/quick_service_screen.dart';
import 'package:rodex_movil/features/workshop/work_orders_screen.dart';
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
        permissions: const ['workshop.view', 'workshop.create'],
        planFeatures: const ['workshop'],
      ),
    );
  }
}

class _FakeWorkshop extends WorkshopRepository {
  _FakeWorkshop() : super(ApiClient());
  Map<String, dynamic>? sent;

  @override
  Future<List<WorkOrder>> orders({String? status}) async => [
    WorkOrder.fromJson({
      'id': 9,
      'code': 'OT-00009',
      'status': 'entregada',
      'status_label': 'Entregada',
      'payment_status': 'pagada',
      'total': 10,
      'balance': 0,
      'paid_amount': 10,
      'client': 'Cliente de paso',
      'vehicle': 'CG 150 ROJA',
      'is_quick': true,
    }),
  ];

  @override
  Future<List<Mechanic>> mechanics() async => [
    Mechanic(id: 1, name: 'CARLOS ROJAS'),
  ];

  @override
  Future<WorkOrder> quickService({
    required List<Map<String, dynamic>> services,
    int? mechanicId,
    int? clientId,
    int? vehicleId,
    String? quickVehicle,
    String method = 'efectivo',
    double discount = 0,
    String? notes,
  }) async {
    sent = {
      'services': services,
      'mechanic_id': mechanicId,
      'client_id': clientId,
      'quick_vehicle': quickVehicle,
      'method': method,
      'discount': discount,
    };
    return WorkOrder.fromJson({
      'id': 10,
      'code': 'OT-00010',
      'status': 'entregada',
      'status_label': 'Entregada',
      'payment_status': 'pagada',
      'total': 10,
      'balance': 0,
      'paid_amount': 10,
      'client': 'Cliente de paso',
      'is_quick': true,
      'services': [],
      'parts': [],
      'photos': [],
    });
  }

  @override
  Future<WorkOrder> order(int id) async => (await orders()).first;
}

Widget _app(_FakeWorkshop repo, Widget home) => ProviderScope(
  overrides: [
    authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
    workshopRepositoryProvider.overrideWithValue(repo),
    cashSessionProvider.overrideWith((ref) async => null),
    appointmentMetaProvider.overrideWith(
      (ref) async => AppointmentMeta(
        services: [ServiceOption(id: 1, name: 'AJUSTE DE CADENA', price: 10)],
        mechanics: [],
      ),
    ),
  ],
  child: MaterialApp(home: home),
);

void main() {
  testWidgets('OTs: el FAB ofrece Nueva recepción y Servicio rápido', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkshop();
    await tester.pumpWidget(_app(repo, const WorkOrdersScreen()));
    await tester.pumpAndSettle();

    // Lista: la OT rápida se muestra como "Cliente de paso · … · ⚡ rápida".
    expect(find.textContaining('Cliente de paso'), findsOneWidget);
    expect(find.textContaining('⚡ rápida'), findsOneWidget);

    await tester.tap(find.text('Nueva OT'));
    await tester.pumpAndSettle();
    expect(find.text('Nueva recepción'), findsOneWidget);
    expect(find.text('Servicio rápido'), findsOneWidget);

    await tester.tap(find.text('Servicio rápido'));
    await tester.pumpAndSettle();
    // Abre la pantalla (título en la AppBar) con el aviso inicial.
    expect(find.text('Servicio rápido'), findsOneWidget);
    expect(find.textContaining('Aún no hay servicios'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Servicio rápido: agrega servicio, avisa sin caja y cobra', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkshop();
    await tester.pumpWidget(_app(repo, const QuickServiceScreen()));
    await tester.pumpAndSettle();

    // Sin caja abierta: aviso rojo, pero el botón sigue deshabilitado por no
    // haber servicios (el backend igual rechaza sin caja).
    await tester.scrollUntilVisible(
      find.textContaining('No tienes una caja abierta'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.textContaining('No tienes una caja abierta'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Agregar'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );

    await tester.tap(find.text('Agregar'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('AJUSTE DE CADENA'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar «AJUSTE DE CADENA»'));
    await tester.pumpAndSettle();

    // Vehículo en texto libre y método QR.
    await tester.scrollUntilVisible(
      find.widgetWithText(TextField, 'Vehículo (texto libre, opcional)'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Vehículo (texto libre, opcional)'),
      'cg 150 roja',
    );
    await tester.scrollUntilVisible(
      find.text('QR'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('QR'));
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.text('Cobrar Bs 10.00 y cerrar'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Cobrar Bs 10.00 y cerrar'));
    await tester.pumpAndSettle();

    expect(repo.sent, isNotNull);
    expect(repo.sent!['services'].single['description'], 'AJUSTE DE CADENA');
    expect(repo.sent!['services'].single['price'], 10.0);
    expect(repo.sent!['quick_vehicle'], 'CG 150 ROJA');
    expect(repo.sent!['method'], 'qr');
    expect(repo.sent!['client_id'], isNull);
    // Tras cobrar abre el detalle de la OT.
    expect(find.text('OT-00009'), findsWidgets);
    expect(tester.takeException(), isNull);
    // Drena el temporizador del toast de éxito.
    await tester.pump(const Duration(seconds: 5));
  });
}
