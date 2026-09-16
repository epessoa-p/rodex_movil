import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/upper_case.dart';

void main() {
  testWidgets('UpperCaseTextFormatter: lo escrito queda en MAYÚSCULAS', (
    tester,
  ) async {
    final c = TextEditingController();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TextField(controller: c, inputFormatters: upperCaseFormatters),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), 'juan pérez ñandú');
    expect(c.text, 'JUAN PÉREZ ÑANDÚ');
  });
}
