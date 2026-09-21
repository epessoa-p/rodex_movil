import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/models.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/core/theme.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/reports/accounts_report_repository.dart';
import 'package:rodex_movil/features/reports/accounts_report_screen.dart';
import 'package:rodex_movil/features/reports/report_period.dart';

class _FakeAuth extends AuthController {
  _FakeAuth(Ref ref) : super(ApiClient(), SecureStore(), ref) {
    state = AuthState(
      status: AuthStatus.authenticated,
      me: MeContext(
        user: AppUser(id: 1, name: 'Tester'),
        isSuperAdmin: false,
        company: Company(id: 1, name: 'VR MOTORS'),
        companies: [Company(id: 1, name: 'VR MOTORS')],
        permissions: const ['cash-registers.view', 'accounts-payable.view'],
        planFeatures: const ['cash', 'purchases', 'sales', 'workshop'],
      ),
    );
  }
}

class _FakeAccounts extends AccountsReportRepository {
  _FakeAccounts() : super(ApiClient());
  final calls = <String>[];

  @override
  Future<AccountsReport> get(String kind, ReportPeriod period) async {
    calls.add('$kind:${period.query}');
    if (kind == 'payables') {
      return AccountsReport.fromJson({
        'total': 800,
        'count': 1,
        'aging': [
          {'label': '0–30 días', 'amount': 800},
          {'label': '31–60 días', 'amount': 0},
          {'label': '+60 días', 'amount': 0},
        ],
        'rows': [
          {
            'id': 3,
            'type': 'purchase',
            'code': 'COM-00003',
            'name': 'REPUESTOS SUR',
            'date': '2026-09-15',
            'total': 1200,
            'paid': 400,
            'balance': 800,
            'days': 6,
            'overdue': false,
          },
        ],
      });
    }
    return AccountsReport.fromJson({
      'total': 450,
      'count': 2,
      'aging': [
        {'label': '0–30 días', 'amount': 150},
        {'label': '31–60 días', 'amount': 0},
        {'label': '+60 días', 'amount': 300},
      ],
      'rows': [
        {
          'id': 9,
          'type': 'work_order',
          'code': 'OT-00009',
          'name': 'JUAN PAZ',
          'phone': '70011223',
          'date': '2026-06-01',
          'due_date': '2026-07-01',
          'total': 500,
          'paid': 200,
          'balance': 300,
          'days': 112,
          'overdue': true,
        },
        {
          'id': 4,
          'type': 'sale',
          'code': 'V-00004',
          'name': 'ANA ROJAS',
          'date': '2026-09-10',
          'total': 150,
          'paid': 0,
          'balance': 150,
          'days': 11,
          'overdue': false,
        },
      ],
    });
  }
}

void main() {
  testWidgets('Cuentas: por cobrar (todo lo pendiente) y por pagar', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final repo = _FakeAccounts();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authControllerProvider.overrideWith((ref) => _FakeAuth(ref)),
          accountsReportRepositoryProvider.overrideWithValue(repo),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const AccountsReportScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Arranca en "Todo" (sin filtro de fecha) y muestra total, antigüedad y filas.
    expect(repo.calls.first, 'receivables:{preset: all}');
    expect(find.text('Total por cobrar'), findsOneWidget);
    expect(find.text('Bs 450.00'), findsOneWidget);
    expect(find.text('JUAN PAZ'), findsOneWidget);
    expect(find.textContaining('venció 01/07/2026'), findsOneWidget);
    expect(find.byTooltip('Recordar por WhatsApp'), findsOneWidget);

    // Por pagar.
    await tester.tap(find.text('Por pagar'));
    await tester.pumpAndSettle();
    expect(repo.calls.last, 'payables:{preset: all}');
    expect(find.text('REPUESTOS SUR'), findsOneWidget);
    expect(find.text('Bs 800.00'), findsWidgets);

    // Cambiar el período acota por fecha.
    await tester.tap(find.text('Esta semana'));
    await tester.pumpAndSettle();
    expect(repo.calls.last.contains('from:'), isTrue);
    expect(tester.takeException(), isNull);
  });
}
