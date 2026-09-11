import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/sheet_focus.dart';
import '../../core/providers.dart';
import '../pos/pos_repository.dart' show cashSessionProvider;
import '../treasury/treasury_repository.dart';
import 'purchases_repository.dart';

/// Detalle de una compra (directa o generada por una OC): proveedor, ítems,
/// totales, saldo, historial de pagos y registro de pagos parciales/totales.
class DirectPurchaseDetailScreen extends ConsumerStatefulWidget {
  final int purchaseId;
  final String code;
  const DirectPurchaseDetailScreen({
    super.key,
    required this.purchaseId,
    required this.code,
  });

  @override
  ConsumerState<DirectPurchaseDetailScreen> createState() =>
      _DirectPurchaseDetailScreenState();
}

class _DirectPurchaseDetailScreenState
    extends ConsumerState<DirectPurchaseDetailScreen> {
  DirectPurchaseDetail? _d;
  bool _loading = true;
  bool _changed = false; // hubo pagos: la lista debe recargar al volver
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final d = await ref
          .read(purchasesRepositoryProvider)
          .directPurchaseDetail(widget.purchaseId);
      if (mounted) {
        setState(() {
          _d = d;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _pay(DirectPurchaseDetail d) async {
    final updated = await showModalBottomSheet<DirectPurchaseDetail>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PaySheet(purchase: d),
    );
    if (updated != null && mounted) {
      setState(() {
        _d = updated;
        _changed = true;
      });
      ref.invalidate(cashSessionProvider);
      ref.invalidate(treasuryAccountsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            updated.isPaid
                ? 'Compra pagada por completo.'
                : 'Pago registrado. Saldo: ${money(updated.balance)}',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final canPay =
        ref.watch(authControllerProvider).me?.can('accounts-payable.pay') ??
        false;
    final d = _d;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(title: Text(widget.code)),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('$_error', textAlign: TextAlign.center),
                ),
              )
            : _body(d!),
        bottomNavigationBar: (d != null && canPay && !d.isPaid)
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                    ),
                    icon: const Icon(Icons.payments_outlined),
                    label: Text('Registrar pago · saldo ${money(d.balance)}'),
                    onPressed: () => _pay(d),
                  ),
                ),
              )
            : null,
      ),
    );
  }

  Widget _body(DirectPurchaseDetail d) {
    final fromOrder = d.fromOrder;
    final accent = fromOrder ? Colors.blue : Colors.brown;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        fromOrder ? 'De OC ${d.orderCode}' : 'Compra directa',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: accent,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Text(
                      d.paymentLabel,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: d.isPaid ? Colors.green : Colors.red,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _line('Proveedor', d.supplier ?? '-'),
                _line('Fecha', d.date ?? '-'),
                if (d.invoiceNumber != null && d.invoiceNumber!.isNotEmpty)
                  _line('Factura', d.invoiceNumber!),
                if (d.notes != null && d.notes!.isNotEmpty)
                  _line('Notas', d.notes!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        const Text('Productos', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        for (final it in d.items)
          Card(
            margin: const EdgeInsets.only(bottom: 6),
            child: ListTile(
              dense: true,
              title: Text(it.name ?? 'Producto'),
              subtitle: Text('${qty(it.quantity)} × ${money(it.unitCost)}'),
              trailing: Text(
                money(it.subtotal),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _totalRow('Total', d.total, bold: true),
                _totalRow('Pagado', d.paidAmount),
                if (!d.isPaid)
                  _totalRow('Saldo pendiente', d.balance, color: Colors.red),
              ],
            ),
          ),
        ),
        if (d.payments.isNotEmpty) ...[
          const SizedBox(height: 12),
          const Text(
            'Pagos registrados',
            style: TextStyle(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          for (final p in d.payments)
            Card(
              margin: const EdgeInsets.only(bottom: 6),
              child: ListTile(
                dense: true,
                leading: const Icon(
                  Icons.check_circle_outline,
                  color: Colors.green,
                ),
                title: Text(
                  money(p.amount),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(
                  [
                    p.source,
                    if (p.method != null && p.method!.isNotEmpty) p.method!,
                    ?p.date,
                  ].join('  ·  '),
                ),
              ),
            ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _line(String k, String v) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Text('$k: $v', style: const TextStyle(color: Colors.black87)),
  );

  Widget _totalRow(String k, double v, {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              k,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
                color: color,
              ),
            ),
            Text(
              money(v),
              style: TextStyle(
                fontWeight: (bold || color != null)
                    ? FontWeight.w800
                    : FontWeight.normal,
                color: color,
              ),
            ),
          ],
        ),
      );
}

/// Hoja de pago: monto (parcial o total), origen Caja / Tesorería y notas.
class _PaySheet extends ConsumerStatefulWidget {
  final DirectPurchaseDetail purchase;
  const _PaySheet({required this.purchase});

  @override
  ConsumerState<_PaySheet> createState() => _PaySheetState();
}

class _PaySheetState extends ConsumerState<_PaySheet> {
  late final TextEditingController _amount;
  late final SheetFocus _focus = SheetFocus(this);
  final _reference = TextEditingController();
  String _source = 'cash';
  int? _accountId;
  List<TreasuryAccount> _accounts = [];
  bool _loadingAccounts = false;
  bool _saving = false;

  bool get _canTreasury =>
      ref.read(authControllerProvider).me?.can('treasury.view') ?? false;

  @override
  void initState() {
    super.initState();
    // Por defecto el saldo completo; el usuario lo baja si es parcial.
    _amount = TextEditingController(text: _trim(widget.purchase.balance));
    if (_canTreasury) _loadAccounts();
  }

  @override
  void dispose() {
    _amount.dispose();
    _focus.dispose();
    _reference.dispose();
    super.dispose();
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(2);

  Future<void> _loadAccounts() async {
    setState(() => _loadingAccounts = true);
    try {
      final accounts =
          (await ref.read(treasuryRepositoryProvider).accounts()).accounts;
      if (mounted) {
        setState(() {
          _accounts = accounts;
          _accountId = accounts.isNotEmpty ? accounts.first.id : null;
          _loadingAccounts = false;
        });
      }
    } on ApiException {
      if (mounted) setState(() => _loadingAccounts = false);
    }
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
    final balance = widget.purchase.balance;
    if (amount <= 0) {
      _snack('Ingresa un monto mayor a cero.');
      return;
    }
    if (amount > balance + 0.001) {
      _snack('El monto supera el saldo pendiente (${money(balance)}).');
      return;
    }
    if (_source == 'treasury' && _accountId == null) {
      _snack('Selecciona la cuenta de tesorería.');
      return;
    }

    setState(() => _saving = true);
    try {
      final updated = await ref
          .read(purchasesRepositoryProvider)
          .payPurchase(
            widget.purchase.id,
            amount: amount,
            source: _source,
            treasuryAccountId: _source == 'treasury' ? _accountId : null,
            reference: _reference.text.trim().isEmpty
                ? null
                : _reference.text.trim(),
          );
      if (mounted) Navigator.pop(context, updated);
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
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final balance = widget.purchase.balance;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Registrar pago · ${widget.purchase.code}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              'Saldo pendiente: ${money(balance)}',
              style: const TextStyle(color: Colors.red),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              focusNode: _focus.node,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Monto a pagar',
                prefixText: '$currencySymbol ',
                helperText: 'Puede ser parcial. Máx. ${money(balance)}',
                border: const OutlineInputBorder(),
                suffixIcon: TextButton(
                  onPressed: () =>
                      setState(() => _amount.text = _trim(balance)),
                  child: const Text('Todo'),
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (_canTreasury) ...[
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'cash',
                    label: Text('Caja'),
                    icon: Icon(Icons.savings_outlined),
                  ),
                  ButtonSegment(
                    value: 'treasury',
                    label: Text('Tesorería'),
                    icon: Icon(Icons.account_balance),
                  ),
                ],
                selected: {_source},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _source = s.first),
              ),
              if (_source == 'treasury') ...[
                const SizedBox(height: 12),
                if (_loadingAccounts)
                  const Center(child: CircularProgressIndicator())
                else if (_accounts.isEmpty)
                  const Text(
                    'No hay cuentas de tesorería. Crea una en Tesorería.',
                    style: TextStyle(color: Colors.red),
                  )
                else
                  DropdownButtonFormField<int>(
                    initialValue: _accountId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Cuenta',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      for (final a in _accounts)
                        DropdownMenuItem(
                          value: a.id,
                          child: Text('${a.name} · ${money(a.balance)}'),
                        ),
                    ],
                    onChanged: (v) => setState(() => _accountId = v),
                  ),
              ],
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _reference,
              decoration: const InputDecoration(
                labelText: 'Referencia (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _source == 'treasury'
                  ? 'Se descontará de la cuenta seleccionada.'
                  : 'Saldrá como gasto de tu caja abierta.',
              style: const TextStyle(color: Colors.black54, fontSize: 12),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: const Text('Confirmar pago'),
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
