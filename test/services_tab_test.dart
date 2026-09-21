import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/core/theme.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/workshop/services_repository.dart';
import 'package:rodex_movil/features/workshop/services_screen.dart';

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
          'services.view',
          'services.create',
          'services.edit',
        ],
        planFeatures: const ['workshop'],
      ),
    );
  }
}

class _FakeServices extends ServicesRepository {
  _FakeServices() : super(ApiClient());
  final updates = <Map<String, dynamic>>[];

  @override
  Future<List<ServiceItem>> all() async => [
    ServiceItem(
      id: 1,
      name: 'CAMBIO DE ACEITE',
      price: 50,
      estimatedTime: '30 min',
      active: true,
    ),
    ServiceItem(id: 2, name: 'FRENOS', price: 120, active: true),
    ServiceItem(id: 3, name: 'AFINADO ANTIGUO', price: 90, active: false),
  ];

  @override
  Future<ServiceItem> update(
    int id, {
    required String name,
    required double price,
    String? description,
    String? estimatedTime,
    bool active = true,
  }) async {
    updates.add({'id': id, 'name': name, 'price': price, 'active': active});
    return ServiceItem(id: id, name: name, price: price, active: active);
  }
}

Widget _app(_FakeServices repo) => ProviderScope(
  overrides: [
    authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
    servicesRepositoryProvider.overrideWithValue(repo),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    home: ServicesScreen(embedded: true),
  ),
);

void main() {
  testWidgets('Servicios: lista, inactivo marcado, buscador y edición', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final repo = _FakeServices();
    await tester.pumpWidget(_app(repo));
    await tester.pumpAndSettle();

    expect(find.text('CAMBIO DE ACEITE'), findsOneWidget);
    expect(find.text('FRENOS'), findsOneWidget);
    expect(find.textContaining('inactivo'), findsOneWidget);
    expect(find.text('Nuevo servicio'), findsOneWidget);

    // Buscador filtra en memoria.
    await tester.enterText(find.byType(TextField), 'fren');
    await tester.pumpAndSettle();
    expect(find.text('FRENOS'), findsOneWidget);
    expect(find.text('CAMBIO DE ACEITE'), findsNothing);

    // Editar: abre el formulario con los datos y guarda.
    await tester.tap(find.text('FRENOS'));
    await tester.pumpAndSettle();
    expect(find.text('Editar servicio'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'FRENOS'), findsOneWidget);
    await tester.enterText(find.widgetWithText(TextField, '120'), '130');
    await tester.tap(find.text('Guardar servicio'));
    await tester.pumpAndSettle();

    expect(repo.updates.single['id'], 2);
    expect(repo.updates.single['price'], 130);
    expect(find.text('Editar servicio'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
