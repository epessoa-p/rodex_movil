import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/module_colors.dart';
import '../../core/providers.dart';
import '../../core/whatsapp.dart';
import '../purchases/direct_purchase_detail_screen.dart';
import '../workshop/work_order_detail_screen.dart';
import 'accounts_report_repository.dart';
import 'report_period.dart';

/// Cuentas: **Por cobrar** (ventas a crédito y OTs con saldo) y **Por pagar**
/// (compras a proveedor con saldo). Por defecto "Todo" = todo lo pendiente;
/// el período acota por fecha del documento.
class AccountsReportScreen extends ConsumerStatefulWidget {
  final int initialTab;
  const AccountsReportScreen({super.key, this.initialTab = 0});

  @override
  ConsumerState<AccountsReportScreen> createState() =>
      _AccountsReportScreenState();
}

class _AccountsReportScreenState extends ConsumerState<AccountsReportScreen>
    with SingleTickerProviderStateMixin {
  ReportPeriod _period = ReportPeriod.of(ReportPreset.all);
  TabController? _tabs;

  @override
  void dispose() {
    _tabs?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).me;
    if (me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final canReceivables = me.canAny([
      'cash-registers.view',
      'sales.view',
      'workshop.view',
    ]);
    final canPayables =
        me.planAllows('purchases') &&
        me.canAny([
          'accounts-payable.view',
          'purchases.view',
          'cash-registers.view',
        ]);

    final tabs = [
      if (canReceivables)
        ('Por cobrar', Icons.call_received, ModuleColors.sales, 'receivables'),
      if (canPayables)
        ('Por pagar', Icons.call_made, ModuleColors.purchases, 'payables'),
    ];
    if (tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Cuentas')),
        body: const Center(child: Text('No tienes acceso a este reporte.')),
      );
    }
    if (_tabs == null || _tabs!.length != tabs.length) {
      _tabs?.dispose();
      _tabs = TabController(
        length: tabs.length,
        vsync: this,
        initialIndex: widget.initialTab.clamp(0, tabs.length - 1),
      );
      _tabs!.addListener(() {
        if (!_tabs!.indexIsChanging) setState(() {});
      });
    }
    final active = tabs[_tabs!.index].$3;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Cuentas'),
        bottom: TabBar(
          controller: _tabs,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          tabs: [
            for (final t in tabs)
              Tab(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(t.$2, size: 16),
                    const SizedBox(width: 4),
                    Flexible(child: Text(t.$1, maxLines: 1)),
                  ],
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            height: 3,
            color: active,
          ),
          PeriodChips(
            period: _period,
            onChanged: (p) => setState(() => _period = p),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                for (final t in tabs)
                  _AccountsTab(kind: t.$4, period: _period, color: t.$3),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountsTab extends ConsumerWidget {
  final String kind;
  final ReportPeriod period;
  final Color color;
  const _AccountsTab({
    required this.kind,
    required this.period,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final key = accountsReportKey(kind, period);
    final async = ref.watch(accountsReportProvider(key));
    final receivable = kind == 'receivables';
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(accountsReportProvider(key)),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: 80),
            Center(child: Text('$e', textAlign: TextAlign.center)),
          ],
        ),
        data: (r) => ListView(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
          children: [
            _TotalCard(
              label: receivable ? 'Total por cobrar' : 'Total por pagar',
              total: r.total,
              count: r.count,
              color: color,
              docLabel: receivable ? 'documentos' : 'compras',
            ),
            const SizedBox(height: 10),
            _Aging(buckets: r.aging, color: color),
            const SizedBox(height: 12),
            if (r.rows.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 30),
                child: Center(
                  child: Text(
                    receivable
                        ? 'Nada pendiente de cobro. 🎉'
                        : 'Nada pendiente de pago. 🎉',
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (var i = 0; i < r.rows.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _AccountTile(row: r.rows[i], receivable: receivable),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TotalCard extends StatelessWidget {
  final String label;
  final double total;
  final int count;
  final Color color;
  final String docLabel;
  const _TotalCard({
    required this.label,
    required this.total,
    required this.count,
    required this.color,
    required this.docLabel,
  });

  @override
  Widget build(BuildContext context) => Card(
    color: ModuleColors.soft(color),
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
                  '$count $docLabel',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          FittedBox(
            child: Text(
              money(total),
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: ModuleColors.onSoft(color),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// Antigüedad: 0–30 · 31–60 · +60 días (el +60 en rojo si hay monto).
class _Aging extends StatelessWidget {
  final List<AgingBucket> buckets;
  final Color color;
  const _Aging({required this.buckets, required this.color});

  @override
  Widget build(BuildContext context) {
    if (buckets.isEmpty) return const SizedBox.shrink();
    final colors = [color, Colors.orange.shade800, Colors.red.shade700];
    return Row(
      children: [
        for (var i = 0; i < buckets.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      buckets[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 10,
                        color: Colors.black54,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        money(buckets[i].amount),
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          color: buckets[i].amount > 0
                              ? colors[i.clamp(0, 2)]
                              : Colors.black38,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AccountTile extends ConsumerWidget {
  final AccountRow row;
  final bool receivable;
  const _AccountTile({required this.row, required this.receivable});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = row;
    final ageColor = r.overdue || r.days > 60
        ? Colors.red.shade700
        : r.days > 30
        ? Colors.orange.shade800
        : Colors.black54;
    final typeLabel = switch (r.type) {
      'sale' => 'Venta',
      'work_order' => 'OT',
      _ => 'Compra',
    };
    final meta = [
      '$typeLabel ${r.code}',
      if (r.date != null) ReportPeriod.dmy(r.date!),
      if (r.dueDate != null)
        '${r.overdue ? 'venció' : 'vence'} ${ReportPeriod.dmy(r.dueDate!)}',
      '${r.days} d',
    ].join(' · ');
    final canOpen = r.type == 'work_order' || r.type == 'purchase';
    final hasPhone = WhatsApp.number(r.phone) != null;

    return ListTile(
      dense: true,
      title: Text(r.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        meta,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: ageColor),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                money(r.balance),
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: receivable
                      ? Colors.green.shade800
                      : Colors.red.shade700,
                ),
              ),
              Text(
                'de ${money(r.total)}',
                style: const TextStyle(fontSize: 11, color: Colors.black45),
              ),
            ],
          ),
          if (receivable && hasPhone)
            IconButton(
              tooltip: 'Recordar por WhatsApp',
              visualDensity: VisualDensity.compact,
              icon: const Icon(Icons.chat, color: Color(0xFF25D366), size: 20),
              onPressed: () => _remind(context, ref, r),
            ),
        ],
      ),
      onTap: canOpen ? () => _open(context, r) : null,
    );
  }

  void _open(BuildContext context, AccountRow r) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => r.type == 'work_order'
            ? WorkOrderDetailScreen(orderId: r.id)
            : DirectPurchaseDetailScreen(purchaseId: r.id, code: r.code),
      ),
    );
  }

  Future<void> _remind(BuildContext context, WidgetRef ref, AccountRow r) {
    final company = ref.read(authControllerProvider).me?.company?.name ?? '';
    final doc = r.type == 'sale' ? 'su compra' : 'su orden';
    final msg =
        'Hola ${r.name}, le escribimos${company.isNotEmpty ? ' de $company' : ''}. '
        'Le recordamos que $doc ${r.code} tiene un saldo pendiente de ${money(r.balance)}'
        '${r.dueDate != null ? ' (vence ${ReportPeriod.dmy(r.dueDate!)})' : ''}. '
        '¡Gracias!';
    return WhatsApp.openChat(r.phone, msg);
  }
}
