import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../pos/pos_repository.dart';
import '../treasury/treasury_repository.dart';
import 'mechanic_payment_pdf.dart';
import 'mechanic_payments_repository.dart';
import 'work_order_detail_screen.dart';

const _dowFull = [
  'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado', 'domingo'
];

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

  /// Fecha con el día en texto: "Lunes 25/08/2026".
  String _fmtDate(String? iso) {
    if (iso == null) return '';
    final d = DateTime.tryParse(iso);
    if (d == null) return iso;
    final day = _dowFull[d.weekday - 1];
    return '${day[0].toUpperCase()}${day.substring(1)} '
        '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
  }

  Future<void> _openOrder(int orderId) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WorkOrderDetailScreen(orderId: orderId),
    ));
    if (mounted) ref.invalidate(mechanicDetailProvider(widget.mechanicId));
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
                              secondary: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(money(o.commission),
                                      style: const TextStyle(
                                          fontWeight: FontWeight.w700)),
                                  IconButton(
                                    tooltip: 'Ver detalle',
                                    visualDensity: VisualDensity.compact,
                                    icon: const Icon(Icons.visibility_outlined,
                                        size: 20),
                                    onPressed: () => _openOrder(o.orderId),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      const SizedBox(height: 16),
                      Text('Pagos realizados (${d.payments.length})',
                          style: const TextStyle(fontWeight: FontWeight.w700)),
                      if (d.payments.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text('Aún no hay pagos.',
                              style: TextStyle(color: Colors.black54)),
                        )
                      else
                        for (final p in d.payments)
                          Card(
                            margin: const EdgeInsets.only(bottom: 6),
                            child: ExpansionTile(
                              leading: const Icon(Icons.check_circle,
                                  color: Colors.green),
                              title: Text(_fmtDate(p.date),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700)),
                              subtitle: Text(
                                  '${p.orders.length} OT(s) · ${(p.method ?? 'efectivo')} · ${p.sourceLabel}'),
                              trailing: Text(money(p.amount),
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      color: Colors.green)),
                              childrenPadding:
                                  const EdgeInsets.fromLTRB(16, 0, 16, 8),
                              children: [
                                for (final o in p.orders)
                                  Padding(
                                    padding:
                                        const EdgeInsets.symmetric(vertical: 2),
                                    child: Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                              '${o.code}  ·  ${_fmtDate(o.date)}',
                                              style: const TextStyle(
                                                  fontSize: 13)),
                                        ),
                                        Text(money(o.commission),
                                            style:
                                                const TextStyle(fontSize: 13)),
                                        const SizedBox(width: 6),
                                        IconButton(
                                          tooltip: 'Ver detalle',
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(),
                                          icon: const Icon(
                                              Icons.visibility_outlined,
                                              size: 18),
                                          onPressed: () => _openOrder(o.orderId),
                                        ),
                                      ],
                                    ),
                                  ),
                                if (p.notes != null && p.notes!.isNotEmpty)
                                  Padding(
                                    padding: const EdgeInsets.only(top: 4),
                                    child: Text(p.notes!,
                                        style: const TextStyle(
                                            fontSize: 12,
                                            fontStyle: FontStyle.italic,
                                            color: Colors.black54)),
                                  ),
                                const SizedBox(height: 6),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.share_outlined,
                                        size: 18),
                                    label: const Text('Compartir comprobante'),
                                    onPressed: () => _shareReceipt(p, d.name),
                                  ),
                                ),
                              ],
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

  Future<void> _shareReceipt(MechanicPaymentItem pago, String mechanicName) async {
    try {
      final company = ref.read(authControllerProvider).me?.company?.name;
      final bytes = await buildMechanicPaymentPdf(pago,
          mechanicName: mechanicName, company: company);
      await Printing.sharePdf(
          bytes: bytes, filename: 'comprobante-${pago.id}.pdf');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No se pudo generar el PDF: $e')));
      }
    }
  }

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
  late final TextEditingController _amount =
      TextEditingController(text: widget.commissionTotal.toStringAsFixed(2));
  final _notes = TextEditingController();
  String _source = 'cash';
  List<TreasuryAccount> _accounts = [];
  int? _accountId;
  bool _loadingAccounts = true;
  bool _saving = false;

  bool get _canTreasury =>
      ref.read(authControllerProvider).me?.can('treasury.view') ?? false;

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
    _amount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) {
      _snack('Ingresa un monto válido.');
      return;
    }
    if (_source == 'treasury' && _accountId == null) {
      _snack('Elige la cuenta de tesorería.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(mechanicPaymentsRepositoryProvider).pay(
            mechanicId: widget.mechanicId,
            workOrderIds: widget.workOrderIds,
            amount: amount,
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
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('${widget.workOrderIds.length} OT(s) · comisión',
                  style: const TextStyle(color: Colors.black54, fontSize: 13)),
              Text(money(widget.commissionTotal),
                  style: const TextStyle(color: Colors.black54, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            decoration: InputDecoration(
              labelText: 'Total a pagar',
              helperText:
                  'Se propone la comisión de las OTs; puedes ajustarlo. Las OTs quedan vinculadas al pago.',
              prefixText: '$currencySymbol ',
              border: const OutlineInputBorder(),
            ),
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
