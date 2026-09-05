import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import 'direct_purchase_detail_screen.dart';
import 'direct_purchase_screen.dart';
import 'new_purchase_order_screen.dart';
import 'po_receive_screen.dart';
import 'purchases_repository.dart';

/// Compras: órdenes de compra (por recibir) + compras directas, en un listado.
class ReceptionsScreen extends ConsumerStatefulWidget {
  const ReceptionsScreen({super.key});

  @override
  ConsumerState<ReceptionsScreen> createState() => _ReceptionsScreenState();
}

/// Item unificado del listado (OC o compra directa).
class _Item {
  final bool isOrder; // true = OC, false = compra directa
  final int id;
  final String code;
  final String? supplier;
  final String? date;
  final double total;
  final String statusLabel;
  final Color color;
  final VoidCallback? onTap;
  _Item({
    required this.isOrder,
    required this.id,
    required this.code,
    this.supplier,
    this.date,
    required this.total,
    required this.statusLabel,
    required this.color,
    this.onTap,
  });
}

class _ReceptionsScreenState extends ConsumerState<ReceptionsScreen> {
  List<_Item> _items = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final me = ref.read(authControllerProvider).me;
    final repo = ref.read(purchasesRepositoryProvider);
    try {
      final orders = await repo.receivableOrders();

      List<DirectPurchaseSummary> purchases = [];
      if (me?.can('purchases.view') ?? false) {
        try {
          purchases = await repo.directPurchases();
        } on ApiException {
          purchases = []; // sin permiso u otro error: solo OCs
        }
      }

      final items = <_Item>[
        for (final po in orders)
          _Item(
            isOrder: true,
            id: po.id,
            code: po.code,
            supplier: po.supplier,
            date: po.date,
            total: po.total,
            statusLabel:
                po.status == 'partial' ? 'Recibida parcial' : 'Enviada',
            color: po.status == 'partial' ? Colors.orange : Colors.blue,
            onTap: () => _receive(po),
          ),
        for (final c in purchases)
          _Item(
            isOrder: false,
            id: c.id,
            code: c.code,
            supplier: c.supplier,
            date: c.date,
            total: c.total,
            statusLabel: c.paymentLabel,
            color: switch (c.paymentStatus) {
              'paid' => Colors.green,
              'partial' => Colors.orange,
              _ => Colors.red,
            },
            onTap: () => _openPurchase(c),
          ),
      ]..sort((a, b) => (b.date ?? '').compareTo(a.date ?? ''));

      if (mounted) setState(() { _items = items; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _receive(PoSummary po) async {
    final received = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PoReceiveScreen(orderId: po.id, code: po.code),
      ),
    );
    if (received == true) _load();
  }

  void _openPurchase(DirectPurchaseSummary c) {
    Navigator.of(context).push(MaterialPageRoute(
      builder: (_) =>
          DirectPurchaseDetailScreen(purchaseId: c.id, code: c.code),
    ));
  }

  Future<void> _newOrder() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NewPurchaseOrderScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _directPurchase() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const DirectPurchaseScreen()),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).me;
    final canOrder = me?.can('purchase-orders.create') ?? false;
    final canDirect =
        (me?.planAllows('purchases') ?? false) && (me?.can('purchases.create') ?? false);

    return Scaffold(
      appBar: AppBar(title: const Text('Compras')),
      body: Column(
        children: [
          if (canOrder || canDirect)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
              child: Row(
                children: [
                  if (canOrder)
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(46)),
                        icon: const Icon(Icons.receipt_long_outlined, size: 18),
                        label: const Text('Nueva OC'),
                        onPressed: _newOrder,
                      ),
                    ),
                  if (canOrder && canDirect) const SizedBox(width: 10),
                  if (canDirect)
                    Expanded(
                      child: FilledButton.icon(
                        style: FilledButton.styleFrom(
                            backgroundColor: Colors.brown,
                            minimumSize: const Size.fromHeight(46)),
                        icon: const Icon(Icons.shopping_bag_outlined, size: 18),
                        label: const Text('Compra directa'),
                        onPressed: _directPurchase,
                      ),
                    ),
                ],
              ),
            ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? _ErrorState(message: '$_error', onRetry: _load)
                    : RefreshIndicator(
                        onRefresh: _load,
                        child: _items.isEmpty
                            ? ListView(children: const [
                                SizedBox(height: 120),
                                Icon(Icons.inventory_2_outlined,
                                    size: 56, color: Colors.black26),
                                SizedBox(height: 12),
                                Center(child: Text('No hay compras registradas.')),
                              ])
                            : ListView.separated(
                                itemCount: _items.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) => _row(_items[i]),
                              ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _row(_Item it) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: (it.isOrder ? Colors.blue : Colors.brown)
            .withValues(alpha: .12),
        child: Icon(it.isOrder ? Icons.receipt_long : Icons.shopping_bag_outlined,
            color: it.isOrder ? Colors.blue : Colors.brown),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
            decoration: BoxDecoration(
              color: (it.isOrder ? Colors.blue : Colors.brown)
                  .withValues(alpha: .12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(it.isOrder ? 'OC' : 'Compra',
                style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: it.isOrder ? Colors.blue : Colors.brown)),
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Text(it.code,
                style: const TextStyle(fontWeight: FontWeight.w700),
                overflow: TextOverflow.ellipsis),
          ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text([
            it.supplier ?? 'Sin proveedor',
            if (it.date != null) it.date!,
          ].join('  ·  ')),
          Text(it.statusLabel,
              style: TextStyle(
                  fontSize: 12, color: it.color, fontWeight: FontWeight.w600)),
        ],
      ),
      trailing: Text(money(it.total),
          style: const TextStyle(fontWeight: FontWeight.w700)),
      onTap: it.onTap,
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: Colors.red, size: 44),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Reintentar'),
            ),
          ],
        ),
      ),
    );
  }
}
