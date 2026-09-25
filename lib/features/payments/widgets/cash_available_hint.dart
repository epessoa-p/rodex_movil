import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/format.dart';
import '../../pos/pos_repository.dart' show cashSessionProvider;

/// "Cuánto hay en caja ahora": caja abierta del usuario y su efectivo
/// disponible (apertura + ingresos − egresos). Si [amount] supera lo
/// disponible, se marca en rojo. Sin caja abierta, avisa.
///
/// En un **cobro** (el dinero entra) el disponible no aporta: con
/// [incoming] = true solo avisa si NO hay caja abierta (que es lo que
/// impediría cobrar) y no muestra nada cuando sí la hay.
class CashAvailableHint extends ConsumerStatefulWidget {
  /// Monto a pagar (fijo) o el controlador del campo de monto (se sigue en vivo).
  final double? amount;
  final TextEditingController? amountController;

  /// Cobro (entra dinero): sin datos de saldo, solo el aviso de caja cerrada.
  final bool incoming;
  const CashAvailableHint({
    super.key,
    this.amount,
    this.amountController,
    this.incoming = false,
  });

  @override
  ConsumerState<CashAvailableHint> createState() => _CashAvailableHintState();
}

class _CashAvailableHintState extends ConsumerState<CashAvailableHint> {
  @override
  void initState() {
    super.initState();
    // Refresca el saldo al abrir la hoja (tras el build, para no tocar el
    // árbol del padre durante su construcción).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.invalidate(cashSessionProvider);
    });
  }

  double? _amountFrom(TextEditingValue v) =>
      double.tryParse(v.text.replaceAll(',', '.'));

  @override
  Widget build(BuildContext context) {
    final c = widget.amountController;
    if (c == null) return _body(widget.amount);
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: c,
      builder: (_, v, _) => _body(_amountFrom(v)),
    );
  }

  Widget _body(double? amount) {
    final async = ref.watch(cashSessionProvider);
    return async.when(
      loading: () => widget.incoming
          ? const SizedBox.shrink()
          : const Padding(
              padding: EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Consultando caja…',
                    style: TextStyle(color: Colors.black54, fontSize: 12),
                  ),
                ],
              ),
            ),
      error: (_, _) => const SizedBox.shrink(),
      data: (s) {
        if (s == null) {
          return _box(
            color: Colors.red,
            icon: Icons.lock_outline,
            text: widget.incoming
                ? 'No tienes una caja abierta: ábrela para poder cobrar.'
                : 'No tienes una caja abierta: abre tu caja para pagar desde ella.',
          );
        }
        // Cobro con caja abierta: no hace falta mostrar el saldo.
        if (widget.incoming) return const SizedBox.shrink();
        final available = s.expectedAmount;
        final over = amount != null && amount > available + 0.009;
        final name = [
          if (s.cashRegister != null && s.cashRegister!.isNotEmpty)
            s.cashRegister!,
          if (s.branch != null && s.branch!.isNotEmpty) s.branch!,
        ].join(' · ');
        return _box(
          color: over ? Colors.red : Colors.green.shade700,
          icon: over ? Icons.warning_amber_rounded : Icons.savings_outlined,
          text:
              '${name.isEmpty ? 'Caja abierta' : name}\n'
              'Disponible en caja: ${money(available)}'
              '${over ? ' · el monto supera lo disponible' : ''}',
        );
      },
    );
  }

  Widget _box({
    required Color color,
    required IconData icon,
    required String text,
  }) => Container(
    margin: const EdgeInsets.only(top: 6),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withValues(alpha: .35)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: color),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(fontSize: 12, color: color, height: 1.3),
          ),
        ),
      ],
    ),
  );
}
