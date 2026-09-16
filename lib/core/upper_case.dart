import 'package:flutter/services.dart';

/// Mayúsculas automáticas en los campos de texto, como en la web (nombres,
/// descripciones, direcciones, notas…). No se aplica a email, usuario,
/// contraseña, buscadores, teléfonos ni números.
///
/// Uso: `inputFormatters: upperCaseFormatters` (+ `textCapitalization:
/// TextCapitalization.characters` para que el teclado ya sugiera mayúsculas).
class UpperCaseTextFormatter extends TextInputFormatter {
  const UpperCaseTextFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final upper = newValue.text.toUpperCase();
    if (upper == newValue.text) return newValue;
    // Misma longitud carácter a carácter: la selección se conserva tal cual.
    return newValue.copyWith(text: upper);
  }
}

const upperCaseFormatters = <TextInputFormatter>[UpperCaseTextFormatter()];
