import 'package:flutter/material.dart';

/// Formas de pago: una sola lista para el POS, el Servicio rápido y la caja
/// (la misma que el backend: `CashMovement::SALE_METHODS`). Efectivo siempre
/// está; las demás las activa cada empresa en "Mi empresa → Punto de venta".
const kPaymentMethods = ['efectivo', 'qr', 'transferencia', 'tarjeta'];

const _labels = {
  'efectivo': 'Efectivo',
  'qr': 'QR',
  'transferencia': 'Transferencia',
  'tarjeta': 'Tarjeta',
  'cheque': 'Cheque',
};

const _icons = {
  'efectivo': Icons.payments_outlined,
  'qr': Icons.qr_code_2,
  'transferencia': Icons.account_balance_outlined,
  'tarjeta': Icons.credit_card,
};

/// Sin método (movimientos viejos) cuenta como efectivo, igual que el backend.
bool isCashMethod(String? m) => m == null || m.isEmpty || m == 'efectivo';

String paymentMethodLabel(String? m) =>
    isCashMethod(m) ? 'Efectivo' : (_labels[m] ?? m!);

IconData paymentMethodIcon(String? m) =>
    _icons[isCashMethod(m) ? 'efectivo' : m] ?? Icons.account_balance_wallet;

/// Filtra/ordena lo que llega de la empresa: siempre con efectivo primero.
List<String> normalizePaymentMethods(Iterable<String>? raw) {
  final set = {...?raw};
  return [
    for (final m in kPaymentMethods)
      if (m == 'efectivo' || set.contains(m)) m,
  ];
}

/// Fila de chips para elegir cómo paga el cliente. Si la empresa solo acepta
/// efectivo, no dibuja nada (no hay nada que elegir).
class PaymentMethodChips extends StatelessWidget {
  final List<String> methods;
  final String value;
  final ValueChanged<String> onChanged;

  const PaymentMethodChips({
    super.key,
    required this.methods,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (methods.length < 2) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final m in methods)
          ChoiceChip(
            avatar: Icon(paymentMethodIcon(m), size: 18),
            label: Text(paymentMethodLabel(m)),
            selected: value == m,
            showCheckmark: false,
            onSelected: (_) => onChanged(m),
          ),
      ],
    );
  }
}
