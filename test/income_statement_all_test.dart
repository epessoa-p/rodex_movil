import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/features/reports/income_statement_repository.dart';
import 'package:rodex_movil/features/reports/income_statement_screen.dart';

IncomeStatement _report(String from, String to, double net) => IncomeStatement(
  from: from,
  to: to,
  income: [StatementLine(label: 'Ventas (mostrador)', amount: net + 100)],
  expense: [StatementLine(label: 'Gastos', amount: 100)],
  totalIncome: net + 100,
  totalExpense: 100,
  net: net,
);

void main() {
  testWidgets('Preset "Todo": pide all=1 y muestra "Desde dd/mm/yyyy — hoy"', (
    tester,
  ) async {
    final requestedKeys = <String>[];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          incomeStatementProvider.overrideWith((ref, key) async {
            requestedKeys.add(key);
            // "all" → el backend fija from en el primer movimiento real.
            return key == incomeStatementAllKey
                ? _report('2024-03-17', '2026-09-15', 98765)
                : _report(key.split('|')[0], key.split('|')[1], 500);
          }),
        ],
        child: const MaterialApp(home: IncomeStatementScreen()),
      ),
    );
    await tester.pumpAndSettle();

    // Arranca en "Este mes" con rango explícito.
    expect(requestedKeys.single, isNot(incomeStatementAllKey));
    expect(find.text('Resultado del período'), findsOneWidget);

    await tester.tap(find.text('Todo'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    expect(requestedKeys.last, incomeStatementAllKey);
    expect(find.text('Desde 17/03/2024  —  hoy'), findsOneWidget);
    expect(find.text('Resultado acumulado'), findsOneWidget);
    expect(find.textContaining('98'), findsWidgets);
  });
}
