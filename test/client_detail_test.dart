import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/module_colors.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/clients/client_detail_screen.dart';
import 'package:rodex_movil/features/clients/clients_repository.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(Ref ref, List<String> perms)
    : super(ApiClient(), SecureStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'VR MOTORS'),
        companies: [Company(id: 1, name: 'VR MOTORS')],
        permissions: perms,
        planFeatures: const ['sales', 'workshop'],
      ),
    );
  }
}

/// Payload tal como lo devuelve GET /clients/{id}: alquileres en null
/// (plan sin rentals) → ese tab no se pinta.
const _payload = {
  'id': 7,
  'full_name': 'ANA ROJAS',
  'id_number': '1234567',
  'phone': '70011223',
  'email': 'ana@mail.com',
  'address': 'AV. BANZER 123',
  'notes': 'CLIENTE FRECUENTE',
  'active': true,
  'photo_url': null,
  'created_at': '2026-01-10',
  'counts': {
    'sales': 1,
    'work_orders': 1,
    'vehicles': 1,
    'appointments': 1,
    'rentals': 0,
  },
  'sales': [
    {
      'id': 1,
      'code': 'V-00010',
      'date': '2026-09-01',
      'type': 'Contado',
      'total': 250.0,
      'payment_status': 'Pagado',
    },
  ],
  'work_orders': [
    {
      'id': 5,
      'code': 'OT-00005',
      'date': '2026-09-02',
      'status': 'en_proceso',
      'status_label': 'En proceso',
      'vehicle': 'Honda CG 150',
      'total': 300.0,
      'balance': 100.0,
      'payment_status': 'Parcial',
    },
  ],
  'vehicles': [
    {
      'id': 3,
      'label': 'Honda CG 150',
      'plate': '1234-ABC',
      'year': 2020,
      'color': 'ROJO',
    },
  ],
  'appointments': [
    {
      'id': 9,
      'date': '2026-09-20',
      'time': '10:00',
      'status': 'programada',
      'status_label': 'Programada',
      'services': 'CAMBIO DE ACEITE',
      'work_order_code': null,
    },
  ],
  'rentals': null,
};

class _FakeRepo extends ClientsRepository {
  final updates = <Map<String, dynamic>>[];
  _FakeRepo() : super(ApiClient());

  @override
  Future<ClientDetail> detail(int id) async => ClientDetail.fromJson(_payload);

  @override
  Future<Client> update(
    int id, {
    required String fullName,
    required String phone,
    String? idNumber,
    String? email,
    String? address,
    String? notes,
    bool active = true,
  }) async {
    updates.add({'name': fullName, 'phone': phone, 'active': active});
    return Client(id: id, fullName: fullName, phone: phone);
  }
}

Widget _app(_FakeRepo repo, List<String> perms) => ProviderScope(
  overrides: [
    authControllerProvider.overrideWith((ref) => _FakeAuth(ref, perms)),
    clientsRepositoryProvider.overrideWithValue(repo),
  ],
  child: const MaterialApp(home: ClientDetailScreen(clientId: 7)),
);

void main() {
  testWidgets(
    'Ficha de cliente: datos, tabs con conteo y sin tab de alquileres',
    (tester) async {
      tester.view.physicalSize = const Size(360, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(_app(_FakeRepo(), const ['clients.view']));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      expect(find.text('ANA ROJAS'), findsWidgets);
      expect(find.text('70011223'), findsOneWidget);
      expect(find.text('WhatsApp'), findsOneWidget);
      for (final t in ['Ventas', 'OTs', 'Vehículos', 'Citas']) {
        expect(find.text(t), findsOneWidget);
      }
      expect(find.text('Alquileres'), findsNothing);
      // Sin clients.edit no hay lápiz.
      expect(find.byTooltip('Editar'), findsNothing);

      // Tab Citas muestra la cita (la barra es desplazable a 360 dp).
      await tester.ensureVisible(find.text('Citas'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Citas'));
      await tester.pumpAndSettle();
      expect(find.text('CAMBIO DE ACEITE'), findsOneWidget);
      expect(find.text('Programada'), findsOneWidget);
      // El indicador toma el color del tab activo (Citas = agenda).
      final bar = tester.widget<TabBar>(find.byType(TabBar));
      expect(bar.indicatorColor, ModuleColors.agenda);
    },
  );

  testWidgets('Editar cliente: hoja precargada, guarda con nombre y teléfono', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeRepo();
    await tester.pumpWidget(_app(repo, const ['clients.view', 'clients.edit']));
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Editar'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Editar cliente'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre completo *'),
      'ana rojas perez',
    );
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle();

    expect(repo.updates.single['name'], 'ANA ROJAS PEREZ');
    expect(repo.updates.single['phone'], '70011223');
    expect(find.text('Cliente actualizado.'), findsOneWidget);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
