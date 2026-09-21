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

WorkOrder _order({bool withLines = false}) => WorkOrder.fromJson({
  'id': 5,
  'code': 'OT-00005',
  'status': 'recibida',
  'status_label': 'Recibida',
  'payment_status': 'pendiente',
  'total': 0,
  'balance': 0,
  'paid_amount': 0,
  'client': 'Juan',
  'vehicle': 'Honda',
  'services': withLines
      ? [
          {
            'id': 70,
            'description': 'FRENOS',
            'price': 120,
            'quantity': 1,
            'subtotal': 120,
          },
        ]
      : [],
  'parts': withLines
      ? [
          {
            'id': 80,
            'name': 'PASTILLA DE FRENO',
            'quantity': 2,
            'unit_price': 40,
            'subtotal': 80,
          },
        ]
      : [],
  'photos': [],
});

class _FakeWorkshop extends WorkshopRepository {
  final added = <Map<String, dynamic>>[];
  final removed = <String>[];
  bool withLines;
  _FakeWorkshop({this.withLines = false}) : super(ApiClient());

  @override
  Future<WorkOrder> order(int id) async => _order(withLines: withLines);

  @override
  Future<WorkOrder> addService(
    int orderId, {
    required String description,
    required double price,
    required int quantity,
    int? mechanicId,
  }) async {
    added.add({'description': description, 'price': price, 'qty': quantity});
    return _order();
  }

  @override
  Future<WorkOrder> removeService(int orderId, int serviceLineId) async {
    removed.add('service:$serviceLineId');
    return _order();
  }

  @override
  Future<WorkOrder> removePart(int orderId, int partLineId) async {
    removed.add('part:$partLineId');
    return _order();
  }
}

Widget _app(_FakeWorkshop repo) => ProviderScope(
  overrides: [
    authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
    workshopRepositoryProvider.overrideWithValue(repo),
    appointmentMetaProvider.overrideWith(
      (ref) async => AppointmentMeta(
        services: [
          ServiceOption(id: 1, name: 'CAMBIO DE ACEITE', price: 60),
          ServiceOption(id: 2, name: 'FRENOS', price: 120),
        ],
        mechanics: [],
      ),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: WorkOrderDetailScreen(orderId: 5),
  ),
);

void main() {
  testWidgets(
    'Agregar servicio en OT: hoja grande, elige del catálogo y precarga el precio',
    (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeWorkshop();
      await tester.pumpWidget(_app(repo));
      await tester.pumpAndSettle();

      // El botón está en la cabecera de la tarjeta "Servicios".
      await tester.tap(find.text('Agregar servicio'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      // Escribir "fre" → queda FRENOS; al elegirlo precarga 120.
      await tester.enterText(find.byType(TextField).first, 'fre');
      await tester.pumpAndSettle();
      expect(find.text('CAMBIO DE ACEITE'), findsNothing);
      await tester.tap(find.text('FRENOS'));
      await tester.pumpAndSettle();

      final priceField = tester.widget<TextField>(
        find.widgetWithText(TextField, 'Precio *'),
      );
      expect(priceField.controller!.text, '120.00');

      await tester.tap(find.text('Agregar «FRENOS»'));
      await tester.pumpAndSettle();
      expect(repo.added.single['description'], 'FRENOS');
      expect(repo.added.single['price'], 120.0);
    },
  );

  testWidgets('Agregar servicio nuevo (no está en el catálogo)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkshop();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Agregar servicio'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, 'pintura');
    await tester.pumpAndSettle();
    expect(
      find.text('«PINTURA» se creará como servicio nuevo.'),
      findsOneWidget,
    );
    await tester.enterText(find.widgetWithText(TextField, 'Precio *'), '300');
    await tester.tap(find.text('Agregar «PINTURA»'));
    await tester.pumpAndSettle();
    expect(repo.added.single['description'], 'PINTURA');
    expect(repo.added.single['price'], 300.0);
  });

  testWidgets('Quitar servicio y repuesto de la OT (con confirmación)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkshop(withLines: true);
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('FRENOS'), findsOneWidget);
    expect(find.text('PASTILLA DE FRENO'), findsOneWidget);
    // Dos × (servicio y repuesto).
    expect(find.byTooltip('Quitar'), findsNWidgets(2));

    await tester.tap(find.byTooltip('Quitar').first);
    await tester.pumpAndSettle();
    expect(find.text('¿Quitar el servicio «FRENOS»?'), findsOneWidget);
    await tester.tap(find.text('Quitar'));
    await tester.pumpAndSettle();
    expect(repo.removed, ['service:70']);
  });

  testWidgets('Detalle de OT a 360 dp: recuadros con color y sin excepciones', (
    tester,
  ) async {
    // Ancho de teléfono; alto grande para que el ListView construya todo.
    tester.view.physicalSize = const Size(360, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_app(_FakeWorkshop(withLines: true)));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Cabecera, Fotos, Diagnóstico, Servicios, Repuestos, Totales.
    expect(find.byType(Card), findsNWidgets(6));
    // Cada uno con su franja de color (DecoratedBox con borde izquierdo).
    final stripes = tester
        .widgetList<DecoratedBox>(
          find.descendant(
            of: find.byType(Card),
            matching: find.byType(DecoratedBox),
          ),
        )
        .where(
          (d) =>
              ((d.decoration as BoxDecoration?)?.border as Border?)
                  ?.left
                  .width ==
              4,
        )
        .length;
    expect(stripes, 6);
  });
}
