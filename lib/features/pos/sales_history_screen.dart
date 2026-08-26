import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import 'pos_repository.dart';
import 'receipt_screen.dart';

/// Historial de ventas: lista paginada (scroll infinito) con búsqueda.
/// Al tocar una venta se abre su recibo (detalle completo).
class SalesHistoryScreen extends ConsumerStatefulWidget {
  const SalesHistoryScreen({super.key});

  @override
  ConsumerState<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends ConsumerState<SalesHistoryScreen> {
  final _scroll = ScrollController();
  final _searchCtrl = TextEditingController();
  final _fmtDate = DateFormat('dd/MM/yyyy HH:mm');

  final List<Sale> _sales = [];
  String _query = '';
  int _page = 0; // última página cargada
  bool _hasMore = true;
  bool _loading = false;
  bool _openingDetail = false;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _reload();
  }

  @override
  void dispose() {
    _scroll.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scroll.position.pixels >= _scroll.position.maxScrollExtent - 240) {
      _loadMore();
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
      _sales.clear();
      _page = 0;
      _hasMore = true;
    });
    await _loadMore(reset: true);
  }

  Future<void> _loadMore({bool reset = false}) async {
    if (_loading && !reset) return;
    if (!_hasMore && !reset) return;
    if (!reset) setState(() => _loading = true);

    try {
      final SalesPage res = await ref
          .read(posRepositoryProvider)
          .sales(page: _page + 1, q: _query);
      if (!mounted) return;
      setState(() {
        _sales.addAll(res.items);
        _page = res.page;
        _hasMore = res.hasMore;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  void _search(String value) {
    _query = value.trim();
    _reload();
  }

  Future<void> _open(Sale s) async {
    if (_openingDetail) return;
    setState(() => _openingDetail = true);
    try {
      final full = await ref.read(posRepositoryProvider).saleById(s.id);
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReceiptScreen(sale: full)),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _openingDetail = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ventas')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              controller: _searchCtrl,
              textInputAction: TextInputAction.search,
              onSubmitted: _search,
              decoration: InputDecoration(
                hintText: 'Buscar por código o cliente…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchCtrl.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtrl.clear();
                          _search('');
                        },
                      ),
                isDense: true,
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          Expanded(child: _body()),
        ],
      ),
    );
  }

  Widget _body() {
    if (_loading && _sales.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null && _sales.isEmpty) {
      return _ErrorState(message: '$_error', onRetry: _reload);
    }
    if (_sales.isEmpty) {
      return RefreshIndicator(
        onRefresh: _reload,
        child: ListView(
          children: const [
            SizedBox(height: 120),
            Icon(Icons.receipt_long_outlined,
                size: 56, color: Colors.black26),
            SizedBox(height: 12),
            Center(child: Text('Aún no hay ventas registradas.')),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _reload,
      child: ListView.separated(
        controller: _scroll,
        itemCount: _sales.length + (_hasMore ? 1 : 0),
        separatorBuilder: (_, _) => const Divider(height: 1),
        itemBuilder: (context, i) {
          if (i >= _sales.length) {
            return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(
                child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2)),
              ),
            );
          }
          return _SaleTile(
            sale: _sales[i],
            dateLabel: _sales[i].saleDate != null
                ? _fmtDate.format(_sales[i].saleDate!.toLocal())
                : '',
            onTap: () => _open(_sales[i]),
          );
        },
      ),
    );
  }
}

class _SaleTile extends StatelessWidget {
  final Sale sale;
  final String dateLabel;
  final VoidCallback onTap;
  const _SaleTile(
      {required this.sale, required this.dateLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      title: Row(
        children: [
          Expanded(
            child: Text(sale.code,
                style: const TextStyle(fontWeight: FontWeight.w700)),
          ),
          Text(money(sale.total),
              style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 2),
          Text(sale.client ?? 'Cliente ocasional',
              maxLines: 1, overflow: TextOverflow.ellipsis),
          if (dateLabel.isNotEmpty)
            Text(dateLabel,
                style: const TextStyle(color: Colors.black54, fontSize: 12)),
        ],
      ),
      trailing: _PaymentBadge(status: sale.paymentStatus),
    );
  }
}

class _PaymentBadge extends StatelessWidget {
  final String status;
  const _PaymentBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'pagada' => (Colors.green, 'Pagada'),
      'parcial' => (Colors.orange, 'Parcial'),
      'pendiente' => (Colors.red, 'Pendiente'),
      _ => (Colors.grey, status.isEmpty ? '—' : status),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
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
