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
  _FakeAuth(Ref ref, List<String> methods)
    : super(ApiClient(), SecureStore(), ref) {
    final company = Company(id: 1, name: 'VR MOTORS', paymentMethods: methods);
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: company,
        companies: [company],
        permissions: const ['workshop.view', 'workshop.edit'],
        planFeatures: const ['workshop'],
      ),
    );
  }
}

WorkOrder _order() => WorkOrder.fromJson({
  'id': 5,
  'code': 'OT-00005',
  'status': 'terminada',
  'status_label': 'Terminada',
  'payment_status': 'pendiente',
  'total': 120,
  'balance': 120,
  'paid_amount': 0,
  'client': 'Juan',
  'vehicle': 'Honda',
  'services': [
    {
      'id': 70,
      'description': 'FRENOS',
      'price': 120,
      'quantity': 1,
      'subtotal': 120,
    },
  ],
  'parts': [],
  'photos': [],
});

class _FakeWorkshop extends WorkshopRepository {
  String? sentMethod;
  _FakeWorkshop() : super(ApiClient());

  @override
  Future<WorkOrder> order(int id) async => _order();

  @override
  Future<WorkOrder> deliver(
    int orderId, {
    String? deliveredTo,
    String method = 'efectivo',
  }) async {
    sentMethod = method;
    return _order();
  }
}

Widget _app(_FakeWorkshop repo, List<String> methods) => ProviderScope(
  overrides: [
    authControllerProvider.overrideWith((ref) => _FakeAuth(ref, methods)),
    workshopRepositoryProvider.overrideWithValue(repo),
    appointmentMetaProvider.overrideWith(
      (ref) async => AppointmentMeta(services: [], mechanics: []),
    ),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: WorkOrderDetailScreen(orderId: 5),
  ),
);

Future<void> _openDeliver(WidgetTester tester) async {
  final btn = find.widgetWithText(FilledButton, 'Entregar y cobrar');
  await tester.scrollUntilVisible(
    btn,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.tap(btn);
  await tester.pumpAndSettle();
  expect(tester.takeException(), isNull);
}

void main() {
  setUp(() {});

  testWidgets('Entregar: elige QR entre las formas de la empresa (360 dp)', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkshop();
    await tester.pumpWidget(_app(repo, const ['efectivo', 'qr', 'tarjeta']));
    await tester.pumpAndSettle();
    await _openDeliver(tester);

    expect(find.text('Forma de pago'), findsOneWidget);
    expect(find.byType(ChoiceChip), findsNWidgets(3));
    await tester.tap(find.widgetWithText(ChoiceChip, 'QR'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Cobrar y entregar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(repo.sentMethod, 'qr');
    await tester.pump(const Duration(seconds: 6));
  });

  testWidgets('Entregar: solo efectivo → sin selector, va efectivo', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkshop();
    await tester.pumpWidget(_app(repo, const ['efectivo']));
    await tester.pumpAndSettle();
    await _openDeliver(tester);

    expect(find.text('Forma de pago'), findsNothing);
    expect(find.byType(ChoiceChip), findsNothing);
    await tester.tap(find.widgetWithText(FilledButton, 'Cobrar y entregar'));
    await tester.pumpAndSettle();
    expect(repo.sentMethod, 'efectivo');
    await tester.pump(const Duration(seconds: 6));
  });
}
