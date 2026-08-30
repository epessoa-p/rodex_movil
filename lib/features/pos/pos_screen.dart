import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../clients/clients_screen.dart';
import '../products/products_screen.dart';
import 'cart.dart';
import 'pos_repository.dart';
import 'receipt_screen.dart';
import 'scan_screen.dart';

class PosScreen extends ConsumerStatefulWidget {
  const PosScreen({super.key});

  @override
  ConsumerState<PosScreen> createState() => _PosScreenState();
}

class _PosScreenState extends ConsumerState<PosScreen> {
  Client? _client;
  bool _submitting = false;
  double _discount = 0;
  final _discountCtrl = TextEditingController();

  @override
  void dispose() {
    _discountCtrl.dispose();
    super.dispose();
  }

  /// Descuento efectivo (no negativo y nunca mayor que el subtotal actual).
  double _effectiveDiscount(double subtotal) => _discount.clamp(0, subtotal);

  void _onDiscountChanged(String value) {
    final parsed = double.tryParse(value.replaceAll(',', '.')) ?? 0;
    setState(() => _discount = parsed < 0 ? 0 : parsed);
  }

  Future<void> _addProduct() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductsScreen(
        onPick: (p) {
          ref.read(cartProvider.notifier).add(p);
          Navigator.pop(context);
        },
      ),
    ));
  }

  Future<void> _scan() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => const ScanScreen(),
    ));
    // El carrito es un provider compartido: al volver ya refleja lo escaneado.
  }

  /// Editor de descuento por producto (monto sobre la línea).
  Future<void> _editLineDiscount(CartLine l) async {
    final cart = ref.read(cartProvider.notifier);
    final ctrl = TextEditingController(
        text: l.discount > 0 ? _trimNum(l.discount) : '');
    final value = await showDialog<double>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(l.product.name,
            maxLines: 2, overflow: TextOverflow.ellipsis),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${qty(l.quantity)} × ${money(l.product.price)} = ${money(l.gross)}',
                style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 12),
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: 'Descuento del producto',
                prefixText: '$currencySymbol ',
                helperText: 'Máx ${money(l.gross)}',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          if (l.discount > 0)
            TextButton(
              onPressed: () => Navigator.pop(ctx, 0.0),
              child: const Text('Quitar'),
            ),
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () => Navigator.pop(
                ctx, double.tryParse(ctrl.text.replaceAll(',', '.')) ?? 0),
            child: const Text('Aplicar'),
          ),
        ],
      ),
    );
    if (value != null) cart.setDiscount(l.product.id, value);
  }

  static String _trimNum(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  Future<void> _pickClient() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ClientsScreen(
        onPick: (c) {
          setState(() => _client = c);
          Navigator.pop(context);
        },
      ),
    ));
  }

  Future<void> _checkout() async {
    final cart = ref.read(cartProvider.notifier);
    if (ref.read(cartProvider).isEmpty) return;
    final discount = _effectiveDiscount(cart.total);
    setState(() => _submitting = true);
    try {
      final sale = await ref.read(posRepositoryProvider).createSale(
            clientId: _client?.id,
            items: cart.toItems(),
            discount: discount,
          );
      cart.clear();
      _discount = 0;
      _discountCtrl.clear();
      ref.invalidate(cashSessionProvider);
      if (mounted) {
        Navigator.of(context).pushReplacement(MaterialPageRoute(
          builder: (_) => ReceiptScreen(sale: sale),
        ));
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final lines = ref.watch(cartProvider);
    final cart = ref.read(cartProvider.notifier);
    final session = ref.watch(cashSessionProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Nueva venta'),
        actions: [
          IconButton(
            tooltip: 'Escanear código',
            icon: const Icon(Icons.qr_code_scanner),
            onPressed: _scan,
          ),
          if (lines.isNotEmpty)
            IconButton(
              tooltip: 'Vaciar',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () => cart.clear(),
            ),
        ],
      ),
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (s) {
          if (s == null) return const _NoCashSession();
          return Column(
            children: [
              _ClientBar(client: _client, onTap: _pickClient, onClear: () {
                setState(() => _client = null);
              }),
              Expanded(
                child: lines.isEmpty
                    ? const Center(
                        child: Text('Agrega productos para vender.'))
                    : ListView.separated(
                        itemCount: lines.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (context, i) {
                          final l = lines[i];
                          return ListTile(
                            title: Text(l.product.name),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                    '${money(l.product.price)} c/u  ·  ${money(l.subtotal)}'),
                                if (l.discount > 0)
                                  Text('Desc. ${money(l.discount)}',
                                      style: const TextStyle(
                                          color: Colors.red, fontSize: 12)),
                              ],
                            ),
                            onTap: () => _editLineDiscount(l),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  tooltip: 'Descuento',
                                  visualDensity: VisualDensity.compact,
                                  icon: Icon(
                                    l.discount > 0
                                        ? Icons.sell
                                        : Icons.sell_outlined,
                                    color: l.discount > 0 ? Colors.red : null,
                                    size: 20,
                                  ),
                                  onPressed: () => _editLineDiscount(l),
                                ),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon:
                                      const Icon(Icons.remove_circle_outline),
                                  onPressed: () => cart.setQuantity(
                                      l.product.id, l.quantity - 1),
                                ),
                                Text(qty(l.quantity),
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w700)),
                                IconButton(
                                  visualDensity: VisualDensity.compact,
                                  icon: const Icon(Icons.add_circle_outline),
                                  onPressed: () => cart.setQuantity(
                                      l.product.id, l.quantity + 1),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
              ),
              _CheckoutBar(
                subtotal: cart.total,
                lineDiscount: cart.lineDiscountTotal,
                discount: _effectiveDiscount(cart.total),
                discountCtrl: _discountCtrl,
                onDiscountChanged: _onDiscountChanged,
                canCheckout: lines.isNotEmpty && !_submitting,
                submitting: _submitting,
                onAdd: _addProduct,
                onScan: _scan,
                onCheckout: _checkout,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ClientBar extends StatelessWidget {
  final Client? client;
  final VoidCallback onTap;
  final VoidCallback onClear;
  const _ClientBar(
      {required this.client, required this.onTap, required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      child: ListTile(
        leading: const Icon(Icons.person_outline),
        title: Text(client?.fullName ?? 'Cliente (opcional)'),
        trailing: client != null
            ? IconButton(icon: const Icon(Icons.close), onPressed: onClear)
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

class _CheckoutBar extends StatelessWidget {
  final double subtotal;
  final double lineDiscount;
  final double discount;
  final TextEditingController discountCtrl;
  final ValueChanged<String> onDiscountChanged;
  final bool canCheckout;
  final bool submitting;
  final VoidCallback onAdd;
  final VoidCallback onScan;
  final VoidCallback onCheckout;

  const _CheckoutBar({
    required this.subtotal,
    required this.lineDiscount,
    required this.discount,
    required this.discountCtrl,
    required this.onDiscountChanged,
    required this.canCheckout,
    required this.submitting,
    required this.onAdd,
    required this.onScan,
    required this.onCheckout,
  });

  @override
  Widget build(BuildContext context) {
    final total = (subtotal - discount).clamp(0, subtotal).toDouble();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    icon: const Icon(Icons.qr_code_scanner),
                    label: const Text('Escanear'),
                    onPressed: onScan,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(48)),
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar'),
                    onPressed: onAdd,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            // Descuento (izq) + subtotal de referencia (der)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: TextField(
                    controller: discountCtrl,
                    onChanged: onDiscountChanged,
                    keyboardType: const TextInputType.numberWithOptions(
                        decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Descuento general',
                      prefixText: '$currencySymbol ',
                      isDense: true,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Subtotal',
                        style: TextStyle(color: Colors.black54, fontSize: 12)),
                    Text(money(subtotal),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    if (lineDiscount > 0)
                      Text('Desc. productos ${money(lineDiscount)}',
                          style:
                              const TextStyle(color: Colors.red, fontSize: 11)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Total',
                          style: TextStyle(color: Colors.black54)),
                      Text(money(total),
                          style: const TextStyle(
                              fontSize: 22, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
                Expanded(
                  child: FilledButton.icon(
                    icon: submitting
                        ? const SizedBox(
                            height: 18,
                            width: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check),
                    label: const Text('Cobrar'),
                    onPressed: canCheckout ? onCheckout : null,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NoCashSession extends StatelessWidget {
  const _NoCashSession();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.savings_outlined, size: 56, color: Colors.orange),
            const SizedBox(height: 12),
            const Text('Necesitas abrir tu caja para vender.',
                textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Ir a Caja'),
            ),
          ],
        ),
      ),
    );
  }
}
