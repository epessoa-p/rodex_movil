import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import 'direct_purchase_detail_screen.dart';
import 'direct_purchase_screen.dart';
import 'new_purchase_order_screen.dart';
import 'po_receive_screen.dart';
import 'purchases_repository.dart';
import 'suppliers_screen.dart';

/// Compras: una pantalla con tres tabs inferiores — Compras directas, Órdenes
/// de compra (todas, con estado) y Proveedores. Cada tab se gatea por su
/// permiso; si solo queda uno visible, se muestra sin barra inferior.
class PurchasesScreen extends ConsumerStatefulWidget {
  const PurchasesScreen({super.key});

  @override
  ConsumerState<PurchasesScreen> createState() => _PurchasesScreenState();
}

class _Tab {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget body;
  const _Tab(this.label, this.icon, this.selectedIcon, this.body);
}

class _PurchasesScreenState extends ConsumerState<PurchasesScreen> {
  int _index = 0;

  List<_Tab> _tabs(MeContext me) => [
    if (me.can('purchases.view'))
      const _Tab(
        'Compras',
        Icons.shopping_bag_outlined,
        Icons.shopping_bag,
        _DirectPurchasesTab(),
      ),
    if (me.canAny(['purchase-orders.view', 'goods-receipts.view']))
      const _Tab(
        'OCs',
        Icons.receipt_long_outlined,
        Icons.receipt_long,
        _OrdersTab(),
      ),
    if (me.can('suppliers.view'))
      const _Tab(
        'Proveedores',
        Icons.storefront_outlined,
        Icons.storefront,
        SuppliersTab(),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).me;
    if (me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final tabs = _tabs(me);
    if (tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Compras')),
        body: const Center(child: Text('No tienes acceso a este módulo.')),
      );
    }
    final index = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      appBar: AppBar(title: const Text('Compras')),
      body: IndexedStack(
        index: index,
        children: [for (final t in tabs) t.body],
      ),
      // NavigationBar exige al menos 2 destinos.
      bottomNavigationBar: tabs.length < 2
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: [
                for (final t in tabs)
                  NavigationDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.selectedIcon),
                    label: t.label,
                  ),
              ],
            ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab: Compras directas
// ═══════════════════════════════════════════════════════════════════

class _DirectPurchasesTab extends ConsumerStatefulWidget {
  const _DirectPurchasesTab();

  @override
  ConsumerState<_DirectPurchasesTab> createState() =>
      _DirectPurchasesTabState();
}

enum _PayFilter { all, pending, paid }

class _DirectPurchasesTabState extends ConsumerState<_DirectPurchasesTab> {
  List<DirectPurchaseSummary> _items = [];
  _PayFilter _filter = _PayFilter.all;
  bool _loading = true;
  Object? _error;

  List<DirectPurchaseSummary> get _visible => switch (_filter) {
    _PayFilter.all => _items,
    _PayFilter.pending =>
      _items.where((c) => c.paymentStatus != 'paid').toList(),
    _PayFilter.paid => _items.where((c) => c.paymentStatus == 'paid').toList(),
  };

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
          .directPurchases();
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

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const DirectPurchaseScreen()),
    );
    if (created == true) _load();
  }

  Future<void> _open(DirectPurchaseSummary c) async {
    // Devuelve true si se registraron pagos: el saldo/estado cambió.
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
    final me = ref.watch(authControllerProvider).me;
    final canCreate =
        (me?.planAllows('purchases') ?? false) &&
        (me?.can('purchases.create') ?? false);

    final visible = _visible;

    // Scaffold anidado solo para el FAB: queda flotando sobre la lista, encima
    // de la barra de tabs, y el tab sigue siendo autocontenido.
    return Scaffold(
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: _create,
              icon: const Icon(Icons.add),
              label: const Text('Compra directa'),
            )
          : null,
      body: Column(
        children: [
          _ActionRow(
            child: SegmentedButton<_PayFilter>(
              segments: const [
                ButtonSegment(value: _PayFilter.all, label: Text('Todas')),
                ButtonSegment(
                  value: _PayFilter.pending,
                  label: Text('Por pagar'),
                ),
                ButtonSegment(value: _PayFilter.paid, label: Text('Pagadas')),
              ],
              selected: {_filter},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _filter = s.first),
            ),
          ),
          Expanded(
            child: _ListState(
              loading: _loading,
              error: _error,
              onRetry: _load,
              isEmpty: visible.isEmpty,
              emptyIcon: Icons.shopping_bag_outlined,
              emptyText: switch (_filter) {
                _PayFilter.pending => 'No hay compras por pagar.',
                _PayFilter.paid => 'No hay compras pagadas.',
                _PayFilter.all => 'No hay compras directas.',
              },
              child: ListView.separated(
                // Espacio al final para que el FAB no tape la última fila.
                padding: const EdgeInsets.only(bottom: 88),
                itemCount: visible.length,
                separatorBuilder: (_, _) => const Divider(height: 1),
                itemBuilder: (_, i) {
                  final c = visible[i];
                  final color = switch (c.paymentStatus) {
                    'paid' => Colors.green,
                    'partial' => Colors.orange,
                    _ => Colors.red,
                  };
                  // Las compras nacidas de una OC se distinguen en azul y con
                  // la OC de origen; el estado muestra el saldo si debe algo.
                  return _PurchaseRow(
                    icon: c.fromOrder
                        ? Icons.receipt_long
                        : Icons.shopping_bag_outlined,
                    accent: c.fromOrder ? Colors.blue : Colors.brown,
                    code: c.code,
                    tag: c.fromOrder ? 'De OC ${c.orderCode}' : null,
                    supplier: c.supplier,
                    date: c.date,
                    total: c.total,
                    statusLabel: c.paymentStatus == 'paid'
                        ? c.paymentLabel
                        : '${c.paymentLabel} · saldo ${money(c.balance)}',
                    statusColor: color,
                    onTap: () => _open(c),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Tab: Órdenes de compra (todas)
// ═══════════════════════════════════════════════════════════════════

enum _OrderFilter { all, pending }

class _OrdersTab extends ConsumerStatefulWidget {
  const _OrdersTab();

  @override
  ConsumerState<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends ConsumerState<_OrdersTab> {
  List<PoSummary> _items = [];
  _OrderFilter _filter = _OrderFilter.all;
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
          .orders(all: true);
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

  Future<void> _create() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const NewPurchaseOrderScreen()),
    );
    if (created == true) _load();
  }

  /// Pendiente → pantalla de recibir; recibida/anulada → la misma pantalla en
  /// solo lectura (ella decide por el estado de la OC).
  Future<void> _open(PoSummary po) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PoReceiveScreen(orderId: po.id, code: po.code),
      ),
    );
    if (changed == true) _load();
  }

  List<PoSummary> get _visible => _filter == _OrderFilter.pending
      ? _items.where((p) => p.isReceivable).toList()
      : _items;

  static Color _colorFor(String status) => switch (status) {
    'sent' => Colors.blue,
    'partial' => Colors.orange,
    'received' => Colors.green,
    'cancelled' => Colors.red,
    _ => Colors.grey,
  };

  @override
  Widget build(BuildContext context) {
    final canCreate =
        ref.watch(authControllerProvider).me?.can('purchase-orders.create') ??
        false;
    final visible = _visible;

    return Column(
      children: [
        _ActionRow(
          child: Row(
            children: [
              Expanded(
                child: SegmentedButton<_OrderFilter>(
                  segments: const [
                    ButtonSegment(
                      value: _OrderFilter.all,
                      label: Text('Todas'),
                    ),
                    ButtonSegment(
                      value: _OrderFilter.pending,
                      label: Text('Pendientes'),
                    ),
                  ],
                  selected: {_filter},
                  showSelectedIcon: false,
                  onSelectionChanged: (s) => setState(() => _filter = s.first),
                ),
              ),
              if (canCreate) ...[
                const SizedBox(width: 8),
                FilledButton.icon(
                  style: FilledButton.styleFrom(minimumSize: const Size(0, 46)),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Nueva OC'),
                  onPressed: _create,
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: _ListState(
            loading: _loading,
            error: _error,
            onRetry: _load,
            isEmpty: visible.isEmpty,
            emptyIcon: Icons.receipt_long_outlined,
            emptyText: _filter == _OrderFilter.pending
                ? 'No hay órdenes pendientes de recibir.'
                : 'No hay órdenes de compra.',
            child: ListView.separated(
              itemCount: visible.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final po = visible[i];
                return _PurchaseRow(
                  icon: Icons.receipt_long,
                  accent: Colors.blue,
                  code: po.code,
                  supplier: po.supplier,
                  date: po.date,
                  total: po.total,
                  statusLabel: po.statusLabel,
                  statusColor: _colorFor(po.status),
                  onTap: () => _open(po),
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// Piezas compartidas
// ═══════════════════════════════════════════════════════════════════

/// Fila de acciones/filtros arriba de cada lista.
class _ActionRow extends StatelessWidget {
  final Widget child;
  const _ActionRow({required this.child});

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.fromLTRB(12, 12, 12, 8), child: child);
}

/// Loading / error / vacío / lista, con pull-to-refresh.
class _ListState extends StatelessWidget {
  final bool loading;
  final Object? error;
  final Future<void> Function() onRetry;
  final bool isEmpty;
  final IconData emptyIcon;
  final String emptyText;
  final Widget child;

  const _ListState({
    required this.loading,
    required this.error,
    required this.onRetry,
    required this.isEmpty,
    required this.emptyIcon,
    required this.emptyText,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) return const Center(child: CircularProgressIndicator());
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 44),
              const SizedBox(height: 12),
              Text('$error', textAlign: TextAlign.center),
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
    return RefreshIndicator(
      onRefresh: onRetry,
      child: isEmpty
          ? ListView(
              children: [
                const SizedBox(height: 120),
                Icon(emptyIcon, size: 56, color: Colors.black26),
                const SizedBox(height: 12),
                Center(child: Text(emptyText)),
              ],
            )
          : child,
    );
  }
}

/// Fila de OC o compra directa: código, proveedor, fecha, estado y total.
class _PurchaseRow extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String code;
  final String? tag;
  final String? supplier;
  final String? date;
  final double total;
  final String statusLabel;
  final Color statusColor;
  final VoidCallback onTap;

  const _PurchaseRow({
    required this.icon,
    required this.accent,
    required this.code,
    this.tag,
    required this.supplier,
    required this.date,
    required this.total,
    required this.statusLabel,
    required this.statusColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: accent.withValues(alpha: .12),
        child: Icon(icon, color: accent),
      ),
      title: Row(
        children: [
          Flexible(
            child: Text(
              code,
              style: const TextStyle(fontWeight: FontWeight.w700),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (tag != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: .12),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                tag!,
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text([supplier ?? 'Sin proveedor', ?date].join('  ·  ')),
          Text(
            statusLabel,
            style: TextStyle(
              fontSize: 12,
              color: statusColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
      trailing: Text(
        money(total),
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      onTap: onTap,
    );
  }
}
