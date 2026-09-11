import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/purchases/purchases_repository.dart';
import 'package:rodex_movil/features/purchases/receptions_screen.dart';

/// AuthController ya autenticado con los permisos indicados (sin tocar la red).
class _FakeAuth extends AuthController {
  _FakeAuth(Ref ref, List<String> permissions)
      : super(ApiClient(), SecureStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'VR MOTORS'),
        companies: [Company(id: 1, name: 'VR MOTORS')],
        permissions: permissions,
        planFeatures: const ['purchases'],
      ),
    );
  }
}

class _FakeRepo extends PurchasesRepository {
  _FakeRepo() : super(ApiClient());

  @override
  Future<List<PoSummary>> orders({bool all = false}) async => [
        PoSummary(
            id: 1, code: 'OC-00001', supplier: 'Yamaha SRL', status: 'sent',
            statusLabel: 'Enviada', date: '2026-09-10', total: 500),
        // La OC RECIBIDA debe seguir apareciendo (el bug reportado).
        PoSummary(
            id: 2, code: 'OC-00002', supplier: 'Honda Import', status: 'received',
            statusLabel: 'Recibida', date: '2026-09-09', total: 1200),
      ];

  @override
  Future<List<DirectPurchaseSummary>> directPurchases() async => [
        DirectPurchaseSummary(
            id: 7, code: 'COM-00007', supplier: 'Ferretería', date: '2026-09-11',
            total: 80, paymentStatus: 'paid', paymentLabel: 'Pagada'),
      ];

  @override
  Future<List<Supplier>> suppliers({String q = ''}) async =>
      [Supplier(id: 3, name: 'Yamaha SRL')];
}

Widget _app(List<String> perms) => ProviderScope(
      overrides: [
        purchasesRepositoryProvider.overrideWithValue(_FakeRepo()),
        authControllerProvider.overrideWith((ref) => _FakeAuth(ref, perms)),
      ],
      child: const MaterialApp(home: PurchasesScreen()),
    );

void main() {
  testWidgets('Con todos los permisos: 3 tabs, y la OC recibida sigue visible',
      (tester) async {
    await tester.pumpWidget(_app(const [
      'purchases.view', 'purchase-orders.view', 'suppliers.view',
    ]));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.byType(NavigationDestination), findsNWidgets(3));

    // Tab 1 (Compras) por defecto.
    expect(find.text('COM-00007'), findsOneWidget);

    // Tab OCs: pendiente + recibida.
    await tester.tap(find.text('OCs'));
    await tester.pumpAndSettle();
    expect(find.text('OC-00001'), findsOneWidget);
    expect(find.text('OC-00002'), findsOneWidget);
    expect(find.text('Recibida'), findsOneWidget);

    // Filtro "Pendientes" oculta la recibida.
    await tester.tap(find.text('Pendientes'));
    await tester.pumpAndSettle();
    expect(find.text('OC-00001'), findsOneWidget);
    expect(find.text('OC-00002'), findsNothing);

    // Tab Proveedores.
    await tester.tap(find.text('Proveedores'));
    await tester.pumpAndSettle();
    expect(find.text('Yamaha SRL'), findsOneWidget);
  });

  testWidgets('Con un solo permiso: un tab y SIN barra inferior',
      (tester) async {
    await tester.pumpWidget(_app(const ['suppliers.view']));
    await tester.pumpAndSettle();

    expect(find.byType(NavigationBar), findsNothing);
    expect(find.text('Yamaha SRL'), findsOneWidget);
    expect(find.text('Compras'), findsOneWidget); // solo el título del AppBar
  });
}
