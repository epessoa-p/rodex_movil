import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/features/agenda/agenda_repository.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/workshop/workshop_hub_screen.dart';
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
        permissions: const [
          'workshop.view',
          'appointments.view',
          'appointments.create',
          'mechanics.view',
          'mechanics.create',
        ],
        planFeatures: const ['workshop'],
      ),
    );
  }
}

void main() {
  testWidgets(
    'Navegar al hub Taller (push) con 3 FABs: sin assert de Hero duplicado',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
            workOrdersProvider.overrideWith((ref) async => <WorkOrder>[]),
            mechanicsFullProvider.overrideWith((ref) async => <MechanicFull>[]),
            agendaDayProvider.overrideWith(
              (ref, date) async => AgendaDay(
                date: date,
                total: 0,
                programada: 0,
                confirmada: 0,
                completada: 0,
                appointments: const [],
              ),
            ),
            agendaRangeProvider.overrideWith(
              (ref, key) async => <Appointment>[],
            ),
          ],
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const WorkshopHubScreen(),
                      ),
                    ),
                    child: const Text('Ir a Taller'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Ir a Taller'));
      // Pump frame a frame durante la transición: aquí salta el assert de Hero.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull, reason: 'frame $i');
      }
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('Taller'), findsOneWidget);

      // Volver atrás también anima los heroes.
      await tester.pageBack();
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 50));
        expect(tester.takeException(), isNull, reason: 'back frame $i');
      }
      await tester.pumpAndSettle();
    },
  );
}
