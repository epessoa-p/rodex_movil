import 'dart:async';

import 'package:flutter/material.dart';

import 'api_client.dart';

/// Notificación flotante en la parte SUPERIOR de la pantalla.
///
/// Se inserta en el overlay raíz, así que se ve por encima de hojas modales y
/// diálogos — a diferencia del SnackBar, que se dibuja en el Scaffold de
/// abajo y queda tapado por un `showModalBottomSheet`. Un solo toast a la
/// vez; se cierra solo o al tocarlo.
class AppToast {
  AppToast._();

  static OverlayEntry? _current;
  static Timer? _timer;

  static void error(BuildContext context, String message, {String? title}) =>
      _show(
        context,
        message,
        title: title ?? 'No se pudo completar',
        color: const Color(0xFFC62828),
        icon: Icons.error_outline,
      );

  static void success(BuildContext context, String message, {String? title}) =>
      _show(
        context,
        message,
        title: title ?? 'Listo',
        color: const Color(0xFF2E7D32),
        icon: Icons.check_circle_outline,
      );

  static void info(BuildContext context, String message, {String? title}) =>
      _show(
        context,
        message,
        title: title ?? 'Aviso',
        color: const Color(0xFF1565C0),
        icon: Icons.info_outline,
      );

  /// Error de la API con un título claro según el `code` que manda el backend.
  static void apiError(BuildContext context, ApiException e) =>
      error(context, e.message, title: titleForCode(e.code));

  /// Título amigable para los códigos de negocio conocidos (egresos, pagos).
  static String titleForCode(String? code) => switch (code) {
    'insufficient_balance' => 'Fondos insuficientes',
    'no_open_session' => 'Caja cerrada',
    'amount_exceeds_balance' => 'Monto mayor al saldo',
    'branch_already_has_register' => 'Sucursal ocupada',
    'permission_denied' => 'Sin permiso',
    'plan_module_forbidden' => 'Módulo no incluido en tu plan',
    'subscription_inactive' || 'subscription_grace_readonly' => 'Suscripción',
    _ => 'No se pudo completar',
  };

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _current?.remove();
    _current = null;
  }

  static void _show(
    BuildContext context,
    String message, {
    required String title,
    required Color color,
    required IconData icon,
    Duration duration = const Duration(seconds: 4),
  }) {
    dismiss();
    final overlay = Overlay.of(context, rootOverlay: true);
    final entry = OverlayEntry(
      builder: (_) => _Toast(
        title: title,
        message: message,
        color: color,
        icon: icon,
        onTap: dismiss,
      ),
    );
    _current = entry;
    overlay.insert(entry);
    _timer = Timer(duration, dismiss);
  }
}

class _Toast extends StatelessWidget {
  final String title;
  final String message;
  final Color color;
  final IconData icon;
  final VoidCallback onTap;

  const _Toast({
    required this.title,
    required this.message,
    required this.color,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          builder: (_, t, child) => Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, -24 * (1 - t)),
              child: child,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Material(
              color: color,
              elevation: 8,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, color: Colors.white, size: 26),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              message,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.close, color: Colors.white70, size: 18),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
