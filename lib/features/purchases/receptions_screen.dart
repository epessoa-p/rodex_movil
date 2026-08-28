import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import 'new_purchase_order_screen.dart';
import 'po_receive_screen.dart';
import 'purchases_repository.dart';

/// Órdenes de compra por recibir (recepción de mercadería).
class ReceptionsScreen extends ConsumerStatefulWidget {
  const ReceptionsScreen({super.key});

  @override
  ConsumerState<ReceptionsScreen> createState() => _ReceptionsScreenState();
}

class _ReceptionsScreenState extends ConsumerState<ReceptionsScreen> {
  List<PoSummary> _orders = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final orders = await ref.read(purchasesRepositoryProvider).receivableOrders();
      if (mounted) setState(() { _orders = orders; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _open(PoSummary po) async {
    final received = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PoReceiveScreen(orderId: po.id, code: po.code),
      ),
    );
    if (received == true) _load();
  }

  Future<void> _newOrder() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NewPurchaseOrderScreen()),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final canCreate =
        ref.watch(authControllerProvider).me?.can('purchase-orders.create') ??
            false;
    return Scaffold(
      appBar: AppBar(title: const Text('Recepción de mercadería')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _newOrder,
              icon: const Icon(Icons.add),
              label: const Text('Nueva OC'),
            )
          : null,
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? _ErrorState(message: '$_error', onRetry: _load)
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _orders.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 120),
                          Icon(Icons.local_shipping_outlined,
                              size: 56, color: Colors.black26),
                          SizedBox(height: 12),
                          Center(
                              child: Text('No hay órdenes de compra por recibir.')),
                        ])
                      : ListView.separated(
                          itemCount: _orders.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final po = _orders[i];
                            final partial = po.status == 'partial';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: (partial
                                        ? Colors.orange
                                        : Colors.blue)
                                    .withValues(alpha: .12),
                                child: Icon(Icons.receipt_long,
                                    color: partial
                                        ? Colors.orange
                                        : Colors.blue),
                              ),
                              title: Text(po.code,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text([
                                po.supplier ?? 'Sin proveedor',
                                if (po.date != null) po.date!,
                                if (partial) 'Recibida parcial',
                              ].join('  ·  ')),
                              trailing: Text(money(po.total),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              onTap: () => _open(po),
                            );
                          },
                        ),
                ),
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
