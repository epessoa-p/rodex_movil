import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/features/cash/cash_admin_repository.dart';
import 'package:rodex_movil/features/cash/cash_registers_screen.dart';

/// Datos falsos: 2 sucursales, 2 personas; Ana ya tiene caja en Central.
class _FakeRepo extends CashAdminRepository {
  _FakeRepo() : super(ApiClient());

  @override
  Future<List<CashRegisterAdmin>> registers() async => [
    CashRegisterAdmin(
      id: 10,
      name: 'Caja Central Ana',
      branch: 'Central',
      branchId: 1,
      personal: 'Ana',
      personalId: 1,
      active: true,
      hasSession: false,
      hasRecords: true, // congelada
    ),
    CashRegisterAdmin(
      id: 11,
      name: 'Caja Norte Luis',
      branch: 'Norte',
      branchId: 2,
      personal: 'Luis',
      personalId: 2,
      active: true,
      hasSession: false,
    ),
  ];

  @override
  Future<CashRegisterFormData> formData() async => CashRegisterFormData(
    branches: [
      NamedOption(id: 1, name: 'Central'),
      NamedOption(id: 2, name: 'Norte'),
    ],
    personal: [
      NamedOption(id: 1, name: 'Ana'),
      NamedOption(id: 2, name: 'Luis'),
    ],
    taken: [
      TakenPair(registerId: 10, branchId: 1, personalId: 1),
      TakenPair(registerId: 11, branchId: 2, personalId: 2),
    ],
  );
}

void main() {
  test('freeBranchesFor: una caja por sucursal por personal', () async {
    final form = await _FakeRepo().formData();
    // Ana ya tiene caja en Central → solo Norte.
    expect(form.freeBranchesFor(1).map((b) => b.id), [2]);
    // Luis ya tiene en Norte → solo Central.
    expect(form.freeBranchesFor(2).map((b) => b.id), [1]);
    // Editando la caja 10 de Ana, Central sigue disponible para ella.
    expect(form.freeBranchesFor(1, exceptRegisterId: 10).map((b) => b.id), [
      1,
      2,
    ]);
  });

  testWidgets('Caja con registros: candado y no abre el formulario', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [cashAdminRepositoryProvider.overrideWithValue(_FakeRepo())],
        child: const MaterialApp(home: CashRegistersScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.lock_outline), findsOneWidget);

    await tester.tap(find.text('Caja Central Ana'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Caja no editable'), findsOneWidget);
    expect(find.text('Editar caja'), findsNothing);
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();

    // La otra caja (sin registros) sí abre el formulario de edición.
    await tester.tap(find.text('Caja Norte Luis'));
    await tester.pumpAndSettle();
    expect(find.text('Editar caja'), findsOneWidget);
    expect(find.text('Una caja por sucursal por personal'), findsOneWidget);
  });
}
