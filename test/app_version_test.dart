import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/config.dart';

/// La versión que ve el usuario (Perfil) es una constante aparte del
/// `pubspec.yaml`. Si se sube una y se olvida la otra, este test falla.
void main() {
  test('AppConfig.appVersion coincide con la versión del pubspec', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*([0-9]+\.[0-9]+\.[0-9]+)\+([0-9]+)',
      multiLine: true,
    ).firstMatch(pubspec);

    expect(match, isNotNull, reason: 'pubspec.yaml sin línea version:');
    expect(
      AppConfig.appVersion,
      match!.group(1),
      reason:
          'Actualiza AppConfig.appVersion (lib/core/config.dart) a la misma '
          'versión que pubspec.yaml',
    );
  });
}
