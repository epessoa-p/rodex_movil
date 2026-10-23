import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/core/theme.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/clients/client_detail_screen.dart';
import 'package:rodex_movil/features/clients/clients_repository.dart';
import 'package:rodex_movil/features/workshop/work_order_detail_screen.dart';
import 'package:rodex_movil/features/workshop/work_orders_screen.dart';
import 'package:rodex_movil/features/workshop/workshop_repository.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(Ref ref, List<String> perms)
    : super(ApiClient(), SecureStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'TALLER'),
        companies: [Company(id: 1, name: 'TALLER')],
        permissions: perms,
        planFeatures: const ['workshop'],
      ),
    );
  }
}

WorkOrder _wo(int id, String status, {String client = 'JUAN PEREZ'}) =>
    WorkOrder.fromJson({
      'id': id,
      'code': 'OT-0000$id',
      'status': status,
      'status_label': status,
      'payment_status': 'pendiente',
      'total': 100,
      'balance': 40,
      'paid_amount': 60,
      'client': client,
      'client_id': 3,
      'vehicle': 'CG 150',
      'services': [],
      'parts': [],
      'photos': [],
    });

void main() {
  testWidgets('listado: abre en Activas, cambia de estado y busca', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final asked = <(String, String)>[];
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          workOrdersProvider.overrideWith((ref, f) async {
            asked.add(f);
            final (status, q) = f;
            if (q == 'zzz') return <WorkOrder>[];
            return [_wo(1, status.isEmpty ? 'recibida' : status)];
          }),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const WorkOrdersScreen(),
        ),
      ),
    );
    await t.pumpAndSettle();
    expect(asked.last, ('activas', ''));
    expect(find.text('OT-00001'), findsOneWidget);
    expect(find.textContaining('debe'), findsOneWidget);

    await t.tap(find.widgetWithText(ChoiceChip, 'Por cobrar'));
    await t.pumpAndSettle();
    expect(asked.last, ('por_cobrar', ''));

    await t.enterText(find.byKey(const Key('wo_search')), 'zzz');
    await t.pump(const Duration(milliseconds: 500));
    await t.pumpAndSettle();
    expect(asked.last, ('por_cobrar', 'zzz'));
    expect(find.textContaining('Sin órdenes que coincidan'), findsOneWidget);

    await t.tap(find.byTooltip('Limpiar'));
    await t.pumpAndSettle();
    expect(asked.last, ('por_cobrar', ''));
    expect(t.takeException(), isNull);
  });

  Future<void> pumpDetail(WidgetTester t, List<String> perms) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _FakeAuth(ref, perms)),
          workshopRepositoryProvider.overrideWithValue(_FakeWorkshop()),
          clientDetailProvider.overrideWith(
            (ref, id) async => ClientDetail.fromJson({
              'id': id,
              'full_name': 'JUAN PEREZ',
              'phone': '70012345',
            }),
          ),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const WorkOrderDetailScreen(orderId: 1),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  testWidgets('OT: el nombre del cliente abre su ficha', (t) async {
    await pumpDetail(t, const ['workshop.view', 'clients.view']);
    expect(find.byKey(const Key('open_client')), findsOneWidget);
    await t.tap(find.byKey(const Key('open_client')));
    await t.pumpAndSettle();
    expect(find.byType(ClientDetailScreen), findsOneWidget);
    expect(t.takeException(), isNull);
  });

  testWidgets('OT: sin permiso de Clientes el nombre es solo texto', (t) async {
    await pumpDetail(t, const ['workshop.view']);
    expect(find.byKey(const Key('open_client')), findsNothing);
    expect(find.textContaining('JUAN PEREZ'), findsWidgets);
  });
}

class _FakeWorkshop extends WorkshopRepository {
  _FakeWorkshop() : super(ApiClient());

  @override
  Future<WorkOrder> order(int id) async => _wo(id, 'en_proceso');
}
