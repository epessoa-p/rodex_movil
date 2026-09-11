import 'package:flutter/material.dart';

/// Foco diferido para campos dentro de un `showModalBottomSheet`.
///
/// `autofocus: true` en una hoja inferior pide el teclado al hilo nativo en el
/// mismo instante en que la hoja todavía está animando su entrada. En algunos
/// Android (MIUI en particular) ese cruce bloquea el hilo principal y la app
/// queda "sin responder". Pedir el foco cuando la animación ya terminó evita
/// la carrera y mantiene la misma experiencia (el teclado aparece solo).
///
/// Uso: en un `State`, `final _focus = SheetFocus(this);` y en el campo
/// `focusNode: _focus.node` (sin `autofocus`). Llamar `_focus.dispose()`.
class SheetFocus {
  final FocusNode node = FocusNode();

  /// Un poco más que la animación de entrada del bottom sheet (~250 ms).
  static const _settle = Duration(milliseconds: 350);

  SheetFocus(State state) {
    Future.delayed(_settle, () {
      if (state.mounted) node.requestFocus();
    });
  }

  void dispose() => node.dispose();
}
