import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../purchases/direct_purchase_detail_screen.dart';
import '../purchases/purchases_repository.dart';

/// Tab Proveedores (Pagos): cuentas por pagar agrupadas por proveedor, con el
/// total adeudado y la antigüedad de cada factura. Tocar una factura abre el
/// detalle de la compra, que ya permite registrar pagos parciales o totales.
class SuppliersPayableTab extends ConsumerStatefulWidget {
  const SuppliersPayableTab({super.key});

  @override
  ConsumerState<SuppliersPayableTab> createState() =>
      _SuppliersPayableTabState();
}

class _SupplierGroup {
  final String name;
  final List<DirectPurchaseSummary> purchases;
  _SupplierGroup(this.name, this.purchases);

  double get balance => purchases.fold(0, (s, p) => s + p.balance);
  int get oldestDays =>
      purchases.fold(0, (m, p) => (p.daysOld ?? 0) > m ? (p.daysOld ?? 0) : m);
}

class _SuppliersPayableTabState extends ConsumerState<SuppliersPayableTab> {
  List<DirectPurchaseSummary> _items = [];
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
    try {
      final items = await ref
          .read(purchasesRepositoryProvider)
          .directPurchases(unpaid: true);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  /// Agrupa por proveedor; los grupos con la deuda más antigua primero.
  List<_SupplierGroup> get _groups {
    final map = <String, List<DirectPurchaseSummary>>{};
    for (final p in _items) {
      map.putIfAbsent(p.supplier ?? 'Sin proveedor', () => []).add(p);
    }
    return map.entries.map((e) => _SupplierGroup(e.key, e.value)).toList()
      ..sort((a, b) => b.oldestDays.compareTo(a.oldestDays));
  }

  Future<void> _open(DirectPurchaseSummary c) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) =>
            DirectPurchaseDetailScreen(purchaseId: c.id, code: c.code),
      ),
    );
    if (changed == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return _Retry(message: '$_error', onRetry: _load);
    }

    final groups = _groups;
    final total = _items.fold<double>(0, (s, p) => s + p.balance);

    return RefreshIndicator(
      onRefresh: _load,
      child: groups.isEmpty
          ? ListView(
              children: const [
                SizedBox(height: 120),
                Icon(Icons.task_alt, size: 56, color: Colors.green),
                SizedBox(height: 12),
                Center(child: Text('No debes nada a proveedores.')),
              ],
            )
          : ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _TotalHeader(
                  label: 'Total por pagar',
                  amount: total,
                  detail:
                      '${_items.length} ${_items.length == 1 ? 'factura' : 'facturas'} · ${groups.length} ${groups.length == 1 ? 'proveedor' : 'proveedores'}',
                  color: Colors.red,
                ),
                const SizedBox(height: 8),
                for (final g in groups) _groupCard(g),
              ],
            ),
    );
  }

  Widget _groupCard(_SupplierGroup g) {
    final old = g.oldestDays > 30;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      clipBehavior: Clip.antiAlias,
      child: ExpansionTile(
        initiallyExpanded: groupsExpandedByDefault,
        leading: CircleAvatar(
          backgroundColor: (old ? Colors.red : Colors.orange).withValues(
            alpha: .12,
          ),
          child: Icon(
            Icons.storefront_outlined,
            color: old ? Colors.red : Colors.orange,
          ),
        ),
        title: Text(
          g.name,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${g.purchases.length} ${g.purchases.length == 1 ? 'factura' : 'facturas'} · la más antigua hace ${g.oldestDays} días',
          style: TextStyle(fontSize: 12, color: old ? Colors.red : null),
        ),
        trailing: Text(
          money(g.balance),
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
        ),
        children: [
          for (final p in g.purchases)
            ListTile(
              dense: true,
              contentPadding: const EdgeInsets.fromLTRB(20, 0, 16, 0),
              title: Row(
                children: [
                  Text(
                    p.code,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  if (p.fromOrder) ...[
                    const SizedBox(width: 6),
                    Text(
                      '· ${p.orderCode}',
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.black45,
                      ),
                    ),
                  ],
                ],
              ),
              subtitle: Text(
                '${p.date ?? ''} · hace ${p.daysOld ?? 0} días · ${p.paymentLabel}',
                style: TextStyle(
                  fontSize: 12,
                  color: (p.daysOld ?? 0) > 30 ? Colors.red : Colors.black54,
                ),
              ),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    money(p.balance),
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      color: Colors.red,
                    ),
                  ),
                  if (p.paidAmount > 0)
                    Text(
                      'de ${money(p.total)}',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black45,
                      ),
                    ),
                ],
              ),
              onTap: () => _open(p),
            ),
        ],
      ),
    );
  }

  /// Con pocos proveedores conviene verlos abiertos; con muchos, plegados.
  bool get groupsExpandedByDefault => _groups.length <= 3;
}

class _TotalHeader extends StatelessWidget {
  final String label;
  final double amount;
  final String detail;
  final Color color;
  const _TotalHeader({
    required this.label,
    required this.amount,
    required this.detail,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color.withValues(alpha: .08),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  Text(
                    detail,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              money(amount),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Retry extends StatelessWidget {
  final String message;
  final Future<void> Function() onRetry;
  const _Retry({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) => Center(
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
