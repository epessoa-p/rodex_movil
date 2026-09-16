import 'package:flutter/material.dart';

import '../../../core/format.dart';

/// Una fila de ranking: etiqueta + valor principal (según el modo) + el otro
/// valor en pequeño. Es agnóstica del origen (servicios, repuestos, clientes…).
class RankingItem {
  final String label;
  final double amount;
  final double qty;
  const RankingItem({
    required this.label,
    required this.amount,
    required this.qty,
  });
}

/// Tarjeta de ranking con barra proporcional. Reutilizada por el dashboard
/// operativo ("Ventas por servicio") y por Análisis → Top.
///
/// [byAmount] = true ordena/escala por monto y muestra "×qty" en pequeño;
/// false hace lo inverso (cantidad grande, monto en pequeño).
class RankingCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final String? hint;
  final List<RankingItem> items;
  final bool byAmount;
  final String emptyText;

  /// Etiqueta de la cantidad en modo Cantidad ("u." / "OTs" / "ops").
  final String qtyUnit;

  const RankingCard({
    super.key,
    required this.title,
    required this.icon,
    required this.items,
    this.hint,
    this.byAmount = true,
    this.emptyText = 'Sin datos en el período.',
    this.qtyUnit = '',
  });

  double _main(RankingItem i) => byAmount ? i.amount : i.qty;

  String _qtyText(double q) {
    final s = q == q.roundToDouble()
        ? q.toInt().toString()
        : q.toStringAsFixed(1);
    return qtyUnit.isEmpty ? s : '$s $qtyUnit';
  }

  @override
  Widget build(BuildContext context) {
    final max = items.isEmpty
        ? 1.0
        : items.map(_main).reduce((a, b) => a > b ? a : b);
    final primary = Theme.of(context).colorScheme.primary;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: Colors.black54),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                if (hint != null)
                  Text(
                    hint!,
                    style: const TextStyle(fontSize: 11, color: Colors.black45),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            if (items.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  emptyText,
                  style: const TextStyle(color: Colors.black54),
                ),
              )
            else
              for (final s in items) ...[
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        s.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      byAmount ? '×${_qtyText(s.qty)}' : money(s.amount),
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      byAmount ? money(s.amount) : _qtyText(s.qty),
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: max > 0
                        ? (_main(s) / max).clamp(0, 1).toDouble()
                        : 0,
                    minHeight: 6,
                    backgroundColor: primary.withValues(alpha: .10),
                    color: primary,
                  ),
                ),
                const SizedBox(height: 10),
              ],
          ],
        ),
      ),
    );
  }
}
