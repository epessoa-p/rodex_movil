import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../pos/pos_repository.dart';
import '../treasury/treasury_repository.dart';
import 'mechanic_payments_repository.dart';

/// Detalle de un mecánico: OTs pendientes (seleccionables para pagar) y pagadas.
class MechanicPaymentDetailScreen extends ConsumerStatefulWidget {
  final int mechanicId;
  const MechanicPaymentDetailScreen({super.key, required this.mechanicId});

  @override
  ConsumerState<MechanicPaymentDetailScreen> createState() =>
      _MechanicPaymentDetailScreenState();
}

class _MechanicPaymentDetailScreenState
    extends ConsumerState<MechanicPaymentDetailScreen> {
  final Set<int> _selected = {};

  String _fmtDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).me;
    final canPay = me?.can('mechanic-payments.pay') ?? false;
    final async = ref.watch(mechanicDetailProvider(widget.mechanicId));

    return Scaffold(
      appBar: AppBar(title: Text(async.valueOrNull?.name ?? 'Mecánico')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e', textAlign: TextAlign.center)),
        data: (d) {
          // Limpia selección de OTs que ya no estén pendientes.
          _selected.removeWhere(
              (id) => !d.pending.any((o) => o.orderId == id));
          final selectedTotal = d.pending
              .where((o) => _selected.contains(o.orderId))
              .fold<double>(0, (s, o) => s + o.commission);

          return Column(
            children: [
              Expanded(
                child: RefreshIndicator(
                  onRefresh: () async =>
                      ref.invalidate(mechanicDetailProvider(widget.mechanicId)),
                  child: ListView(
                    padding: const EdgeInsets.all(12),
                    children: [
                      _summaryCard(d),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Pendientes (${d.pending.length})',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          if (canPay && d.pending.isNotEmpty)
                            TextButton(
                              onPressed: () => setState(() {
                                if (_selected.length == d.pending.length) {
                                  _selected.clear();
                                } else {
                                  _selected
                                    ..clear()
                                    ..addAll(d.pending.map((o) => o.orderId));
                                }
                              }),
                              child: Text(
                                  _selected.length == d.pending.length
                                      ? 'Quitar todas'
                                      : 'Seleccionar todas'),
                            ),
                        ],
                      ),
                      if (d.pending.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Sin OTs pendientes.',
                              style: TextStyle(color: Colors.black54)),
                        )
                      else
                        for (final o in d.pending)
                          Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: CheckboxListTile(
                              dense: true,
                              value: _selected.contains(o.orderId),
                              onChanged: canPay
                                  ? (v) => setState(() {
                                        if (v == true) {
                                          _selected.add(o.orderId);
                                        } else {
                                          _selected.remove(o.orderId);
                                        }
                                      })
                                  : null,
                              title: Text(o.code,
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600)),
                              subtitle: Text(_fmtDate(o.date)),
                              secondary: Text(money(o.commission),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                            ),
                          ),
                      const SizedBox(height: 16),
                      Text('Pagadas (${d.paid.length})',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (d.paid.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Aún no hay OTs pagadas.',
                              style: TextStyle(color: Colors.black54)),
                        )
                      else
                        for (final o in d.paid)
                          Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ListTile(
                              dense: true,
                              leading: const Icon(Icons.check_circle,
                                  color: Colors.green),
                              title: Text(o.code),
                              subtitle: Text(
                                  'Pagada el ${_fmtDate(o.paymentDate)}'),
                              trailing: Text(money(o.commission)),
                            ),
                          ),
                      const SizedBox(height: 90),
                    ],
                  ),
                ),
              ),
              if (canPay && d.pending.isNotEmpty)
                SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                          backgroundColor: Colors.green,
                          minimumSize: const Size.fromHeight(50)),
                      icon: const Icon(Icons.payments_outlined),
                      label: Text(_selected.isEmpty
                          ? 'Selecciona OTs para pagar'
                          : 'Pagar ${_selected.length} OT(s) · ${money(selectedTotal)}'),
                      onPressed: _selected.isEmpty
                          ? null
                          : () => _openPay(d, selectedTotal),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _summaryCard(MechanicDetail d) => Card(
        color: Colors.green.withValues(alpha: .08),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Pendiente',
                        style: TextStyle(fontSize: 12, color: Colors.black54)),
                    Text(money(d.pendingTotal),
                        style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            color: Colors.red)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('Comisión ${_trim(d.commissionRate)}%',
                      style: const TextStyle(fontSize: 12)),
                  Text('Pagado ${money(d.paidTotal)}',
                      style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ],
          ),
        ),
      );

  Future<void> _openPay(MechanicDetail d, double selectedTotal) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaySheet(
        mechanicId: widget.mechanicId,
        workOrderIds: _selected.toList(),
        commissionTotal: selectedTotal,
      ),
    );
    if (ok == true) {
      _selected.clear();
      ref.invalidate(mechanicDetailProvider(widget.mechanicId));
      ref.invalidate(treasuryAccountsProvider);
      ref.invalidate(cashSessionProvider);
    }
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

class _PaySheet extends ConsumerStatefulWidget {
  final int mechanicId;
  final List<int> workOrderIds;
  final double commissionTotal;
  const _PaySheet({
    required this.mechanicId,
    required this.workOrderIds,
    required this.commissionTotal,
  });

  @override
  ConsumerState<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends ConsumerState<_PaySheet> {
  final _bonus = TextEditingController();
  final _notes = TextEditingController();
  String _source = 'cash';
  List<TreasuryAccount> _accounts = [];
  int? _accountId;
  bool _loadingAccounts = true;
  bool _saving = false;

  bool get _canTreasury =>
      ref.read(authControllerProvider).me?.can('treasury.view') ?? false;

  double get _total =>
      widget.commissionTotal +
      (double.tryParse(_bonus.text.replaceAll(',', '.')) ?? 0);

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    if (!_canTreasury) {
      setState(() => _loadingAccounts = false);
      return;
    }
    try {
      final o = await ref.read(treasuryRepositoryProvider).accounts();
      if (mounted) {
        setState(() {
          _accounts = o.accounts;
          _accountId = o.accounts.isNotEmpty ? o.accounts.first.id : null;
          _loadingAccounts = false;
        });
      }
    } on ApiException {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  @override
  void dispose() {
    _bonus.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_source == 'treasury' && _accountId == null) {
      _snack('Elige la cuenta de tesorería.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(mechanicPaymentsRepositoryProvider).pay(
            mechanicId: widget.mechanicId,
            workOrderIds: widget.workOrderIds,
            bonus: double.tryParse(_bonus.text.replaceAll(',', '.')) ?? 0,
            paymentSource: _source,
            treasuryAccountId: _source == 'treasury' ? _accountId : null,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(e.message);
      }
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Registrar pago',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${widget.workOrderIds.length} OT(s) · comisión'),
              Text(money(widget.commissionTotal)),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _bonus,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Bono / extra (opcional)',
              prefixText: '$currencySymbol ',
              isDense: true,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('Total a pagar',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              Text(money(_total),
                  style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 18,
                      color: Colors.green)),
            ],
          ),
          const SizedBox(height: 14),
          const Text('Pagar con', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          if (_loadingAccounts)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(child: CircularProgressIndicator()),
            )
          else ...[
            if (_canTreasury)
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                      value: 'cash',
                      label: Text('Caja'),
                      icon: Icon(Icons.savings_outlined)),
                  ButtonSegment(
                      value: 'treasury',
                      label: Text('Tesorería'),
                      icon: Icon(Icons.account_balance)),
                ],
                selected: {_source},
                onSelectionChanged: (s) => setState(() => _source = s.first),
              ),
            if (_source == 'treasury') ...[
              const SizedBox(height: 12),
              if (_accounts.isEmpty)
                const Text('No hay cuentas de tesorería. Crea una en Tesorería.',
                    style: TextStyle(color: Colors.red))
              else
                DropdownButtonFormField<int>(
                  initialValue: _accountId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      labelText: 'Cuenta', border: OutlineInputBorder()),
                  items: [
                    for (final a in _accounts)
                      DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.name} · ${money(a.balance)}')),
                  ],
                  onChanged: (v) => setState(() => _accountId = v),
                ),
            ],
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            minLines: 1,
            maxLines: 2,
            decoration: const InputDecoration(
                labelText: 'Notas (opcional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: Colors.green,
                minimumSize: const Size.fromHeight(48)),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: const Text('Registrar pago'),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
