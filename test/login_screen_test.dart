import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/api_client.dart';
import 'package:rodex_movil/core/providers.dart';
import 'package:rodex_movil/core/storage.dart';
import 'package:rodex_movil/features/auth/auth_controller.dart';
import 'package:rodex_movil/features/auth/login_screen.dart';

void main() {
  testWidgets('LoginScreen muestra los campos y el botón', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          // Controlador sin bootstrap() para no tocar el almacenamiento seguro.
          authControllerProvider.overrideWith(
            (ref) => AuthController(ApiClient(), SecureStore(), ref),
          ),
        ],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );

    expect(find.text('Usuario o email'), findsOneWidget);
    expect(find.text('Contraseña'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Iniciar sesión'), findsOneWidget);
  });
}
