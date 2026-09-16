import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/features/clients/clients_screen.dart';
import 'package:rodex_movil/features/pos/pos_repository.dart';

/// Repositorio falso: registra las altas y devuelve el cliente creado.
class _FakePos extends PosRepository {
  final created = <Map<String, String?>>[];
  _FakePos() : super(ApiClient());

  @override
  Future<List<Client>> clients({String q = ''}) async => [];

  @override
  Future<Client> createClient({
    required String fullName,
    String? idNumber,
    String? phone,
  }) async {
    created.add({'name': fullName, 'phone': phone, 'id': idNumber});
    return Client(id: 7, fullName: fullName, phone: phone);
  }
}

void main() {
  testWidgets(
    'Nuevo cliente: sin teléfono → toast arriba y el diálogo sigue; con datos → crea y elige',
    (tester) async {
      final repo = _FakePos();
      Client? picked;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [posRepositoryProvider.overrideWithValue(repo)],
          child: MaterialApp(home: ClientsScreen(onPick: (c) => picked = c)),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Nuevo'));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo cliente'), findsOneWidget);

      // Solo nombre → falta el teléfono (aviso visible sobre el diálogo).
      await tester.enterText(
        find.widgetWithText(TextField, 'Nombre completo *'),
        'Ana Rojas',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(SnackBar), findsNothing);
      expect(find.text('Falta el teléfono'), findsOneWidget);
      expect(find.text('Nuevo cliente'), findsOneWidget); // sigue abierto
      expect(repo.created, isEmpty);

      // Con teléfono → crea, toast verde y vuelve con el cliente elegido.
      await tester.enterText(
        find.widgetWithText(TextField, 'Teléfono *'),
        '70011223',
      );
      await tester.tap(find.text('Guardar'));
      await tester.pump(const Duration(milliseconds: 300));

      expect(repo.created.single['phone'], '70011223');
      expect(find.text('Cliente ANA ROJAS creado.'), findsOneWidget);
      expect(picked?.id, 7);

      // Tras cerrarse el toast, el diálogo ya no está.
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Nuevo cliente'), findsNothing);
    },
  );
}
