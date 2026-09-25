import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/core/theme.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/workshop/work_order_detail_screen.dart';
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
        permissions: const ['workshop.view', 'workshop.edit'],
        planFeatures: const ['workshop'],
      ),
    );
  }
}

Map<String, dynamic> _json({
  required String status,
  bool canReopen = false,
  String? blocked,
}) => {
  'id': 5,
  'code': 'OT-00005',
  'status': status,
  'status_label': status == 'entregada' ? 'Entregada' : 'En proceso',
  'payment_status': status == 'entregada' ? 'pagada' : 'pendiente',
  'total': 120,
  'balance': 0,
  'paid_amount': status == 'entregada' ? 120 : 0,
  'client': 'Cliente de paso',
  'vehicle': 'CG 150 ROJA',
  'mileage': 15230,
  'fuel_level': '1/2',
  'reported_issue': 'RUIDO',
  'is_quick': true,
  'can_reopen': canReopen,
  'reopen_blocked_reason': blocked,
  'services': [],
  'parts': [],
  'photos': [],
};

class _FakeWorkshop extends WorkshopRepository {
  _FakeWorkshop(this._order) : super(ApiClient());
  Map<String, dynamic> _order;
  int reopenCalls = 0;
  Map<String, dynamic>? updated;

  @override
  Future<WorkOrder> order(int id) async => WorkOrder.fromJson(_order);

  @override
  Future<WorkOrder> reopenOrder(int id) async {
    reopenCalls++;
    _order = _json(status: 'terminada');
    return WorkOrder.fromJson(_order);
  }

  @override
  Future<WorkOrder> updateOrder(
    int id, {
    int? clientId,
    int? vehicleId,
    String? quickVehicle,
    int? mileage,
    String? fuelLevel,
    String? reportedIssue,
    String? receivedItems,
    String? notes,
  }) async {
    updated = {
      'mileage': mileage,
      'fuel_level': fuelLevel,
      'reported_issue': reportedIssue,
      'notes': notes,
    };
    return WorkOrder.fromJson(_order);
  }
}

Widget _app(_FakeWorkshop repo) => ProviderScope(
  overrides: [
    authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
    workshopRepositoryProvider.overrideWithValue(repo),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: const WorkOrderDetailScreen(orderId: 5),
  ),
);

void main() {
  testWidgets('OT entregada con caja abierta: se reabre para corregir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkshop(_json(status: 'entregada', canReopen: true));
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    // Cerrada: sin lápiz, con acción de reabrir.
    expect(find.byTooltip('Editar datos'), findsNothing);
    await tester.tap(find.byTooltip('Reabrir para corregir'));
    await tester.pumpAndSettle();

    expect(find.textContaining('Se anulará el cobro'), findsOneWidget);
    await tester.tap(find.text('Reabrir'));
    await tester.pumpAndSettle();

    expect(repo.reopenCalls, 1);
    // Reabierta: ya aparece el lápiz de edición.
    expect(find.byTooltip('Editar datos'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('OT entregada con caja cerrada: avisa el motivo y no reabre', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkshop(
      _json(
        status: 'entregada',
        blocked: 'La caja de ese cobro ya fue cerrada.',
      ),
    );
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('La caja de ese cobro ya fue cerrada.'));
    await tester.pumpAndSettle();

    expect(repo.reopenCalls, 0);
    expect(
      find.textContaining('La caja de ese cobro ya fue cerrada'),
      findsWidgets,
    );
    await tester.pump(const Duration(seconds: 5));
  });

  testWidgets('OT en curso: el lápiz abre la hoja y guarda los datos', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkshop(_json(status: 'en_proceso'));
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar datos'));
    await tester.pumpAndSettle();
    expect(find.text('Editar OT-00005'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Kilometraje'),
      '16000',
    );
    await tester.enterText(
      find.widgetWithText(TextField, 'Falla reportada'),
      'Ruido en frenos',
    );
    await tester.tap(find.text('Guardar cambios'));
    await tester.pumpAndSettle();

    expect(repo.updated!['mileage'], 16000);
    expect(repo.updated!['reported_issue'], 'Ruido en frenos');
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(seconds: 5));
  });
}
