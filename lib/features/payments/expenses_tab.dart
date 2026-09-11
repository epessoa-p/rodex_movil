import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/sheet_focus.dart';
import '../pos/pos_repository.dart' show cashSessionProvider;
import '../treasury/treasury_repository.dart' show treasuryAccountsProvider;
import 'payments_repository.dart';
import 'widgets/payment_source_field.dart';

const _months = [
  'Ene',
  'Feb',
  'Mar',
  'Abr',
  'May',
  'Jun',
  'Jul',
  'Ago',
  'Sep',
  'Oct',
  'Nov',
  'Dic',
];

String _currentPeriod() {
  final now = DateTime.now();
  return '${_months[now.month - 1]} ${now.year}';
}

/// Tab Gastos (Pagos): servicios recurrentes del catálogo con su estado del
/// mes (pagado / sin pagar), pago en un toque con el monto habitual precargado,
/// gasto libre, alta de servicio y últimos gastos.
class ExpensesTab extends ConsumerWidget {
  const ExpensesTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider).me;
    final canPay = me?.can('cash.operate') ?? false;
    final canManage = me?.can('expense-services.manage') ?? false;
    final async = ref.watch(expensesOverviewProvider);

    return Scaffold(
      floatingActionButton: canPay
          ? FloatingActionButton.extended(
              onPressed: () => _otherExpense(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Otro gasto'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(expensesOverviewProvider.future),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(child: Text('$e', textAlign: TextAlign.center)),
            ],
          ),
          data: (o) => ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
            children: [
              Card(
                color: Colors.deepOrange.withValues(alpha: .08),
                child: ListTile(
                  leading: const Icon(
                    Icons.receipt_long,
                    color: Colors.deepOrange,
                  ),
                  title: const Text(
                    'Gastos del mes',
                    style: TextStyle(fontSize: 12, color: Colors.black54),
                  ),
                  subtitle: Text(
                    _currentPeriod(),
                    style: const TextStyle(fontSize: 12),
                  ),
                  trailing: Text(
                    money(o.monthTotal),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: Colors.deepOrange,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ── Servicios recurrentes ──
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Servicios recurrentes',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                  if (canManage)
                    TextButton.icon(
                      onPressed: () => _newService(context, ref),
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Nuevo servicio'),
                    ),
                ],
              ),
              if (o.services.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    'Aún no hay servicios registrados (luz, agua, internet…). '
                    'Agrégalos para pagarlos en un toque y ver qué falta cada mes.',
                    style: TextStyle(color: Colors.black54),
                  ),
                )
              else
                for (final s in o.services)
                  _ServiceCard(
                    service: s,
                    onTap: canPay ? () => _payService(context, ref, s) : null,
                  ),

              // ── Últimos gastos ──
              if (o.recent.isNotEmpty) ...[
                const SizedBox(height: 16),
                const Text(
                  'Últimos gastos',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Card(
                  child: Column(
                    children: [
                      for (final m in o.recent)
                        ListTile(
                          dense: true,
                          title: Text(
                            m.description,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${m.date} · ${m.source}',
                            style: const TextStyle(fontSize: 11),
                          ),
                          trailing: Text(
                            '- ${money(m.amount)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: Colors.red,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _afterPayment(BuildContext context, WidgetRef ref, ExpenseMovement m) {
    ref.invalidate(expensesOverviewProvider);
    ref.invalidate(cashSessionProvider);
    ref.invalidate(treasuryAccountsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Gasto registrado: ${money(m.amount)}')),
    );
  }

  Future<void> _payService(
    BuildContext context,
    WidgetRef ref,
    RecurringService s,
  ) async {
    final m = await showModalBottomSheet<ExpenseMovement>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _ExpenseSheet.service(s),
    );
    if (m != null && context.mounted) _afterPayment(context, ref, m);
  }

  Future<void> _otherExpense(BuildContext context, WidgetRef ref) async {
    final m = await showModalBottomSheet<ExpenseMovement>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _ExpenseSheet.other(),
    );
    if (m != null && context.mounted) _afterPayment(context, ref, m);
  }

  Future<void> _newService(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<RecurringService>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewServiceSheet(),
    );
    if (created != null && context.mounted) {
      ref.invalidate(expensesOverviewProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Servicio "${created.name}" agregado.')),
      );
    }
  }
}

/// Un servicio recurrente con su estado del mes.
class _ServiceCard extends StatelessWidget {
  final RecurringService service;
  final VoidCallback? onTap;
  const _ServiceCard({required this.service, this.onTap});

  static IconData _icon(String type) => switch (type) {
    'basico' => Icons.bolt,
    'externo' => Icons.handshake_outlined,
    'transporte' => Icons.local_shipping_outlined,
    _ => Icons.receipt_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final paid = service.paidThisMonth;
    final color = paid != null ? Colors.green : Colors.orange;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .12),
          child: Icon(_icon(service.type), color: color),
        ),
        title: Text(
          service.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          children: [
            Icon(
              paid != null ? Icons.check_circle : Icons.schedule,
              size: 14,
              color: color,
            ),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                paid != null
                    ? 'Pagado ${paid.date} · ${money(paid.amount)}'
                    : 'Sin pagar este mes · ${service.typeLabel}',
                style: TextStyle(
                  fontSize: 12,
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        trailing: service.defaultAmount > 0
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    'habitual',
                    style: TextStyle(fontSize: 10, color: Colors.black45),
                  ),
                  Text(
                    money(service.defaultAmount),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              )
            : const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}

/// Hoja de gasto: para un servicio del catálogo (monto precargado) o libre.
class _ExpenseSheet extends ConsumerStatefulWidget {
  final RecurringService? service;
  const _ExpenseSheet.service(RecurringService this.service);
  const _ExpenseSheet.other() : service = null;

  @override
  ConsumerState<_ExpenseSheet> createState() => _ExpenseSheetState();
}

class _ExpenseSheetState extends ConsumerState<_ExpenseSheet> {
  late final TextEditingController _amount;
  final _concept = TextEditingController();
  late final TextEditingController _period;
  final _notes = TextEditingController();
  String _kind = 'other'; // solo para gasto libre: other | transport
  PaymentSource? _source = const PaymentSource.cash();
  bool _saving = false;
  // Foco diferido al primer campo (concepto si es gasto libre, monto si es servicio).
  late final SheetFocus _focus = SheetFocus(this);

  bool get _isService => widget.service != null;

  @override
  void initState() {
    super.initState();
    final v = widget.service?.defaultAmount ?? 0;
    _amount = TextEditingController(
      text: v > 0
          ? (v == v.roundToDouble()
                ? v.toStringAsFixed(0)
                : v.toStringAsFixed(2))
          : '',
    );
    _period = TextEditingController(text: _isService ? _currentPeriod() : '');
  }

  @override
  void dispose() {
    for (final c in [_amount, _concept, _period, _notes]) {
      c.dispose();
    }
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) return _snack('Ingresa un monto mayor a cero.');
    if (!_isService && _concept.text.trim().isEmpty) {
      return _snack('Indica el concepto del gasto.');
    }
    final source = _source;
    if (source == null) return _snack('Selecciona la cuenta de tesorería.');

    setState(() => _saving = true);
    try {
      final m = await ref
          .read(paymentsRepositoryProvider)
          .registerExpense(
            kind: _isService ? 'service' : _kind,
            amount: amount,
            source: source.source,
            expenseServiceId: widget.service?.id,
            concept: _isService ? null : _concept.text.trim(),
            period: _period.text.trim().isEmpty ? null : _period.text.trim(),
            treasuryAccountId: source.treasuryAccountId,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (mounted) Navigator.pop(context, m);
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
    final s = widget.service;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              s != null ? 'Pagar ${s.name}' : 'Otro gasto',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (s != null)
              Text(s.typeLabel, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 16),
            if (!_isService) ...[
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'other', label: Text('Operativo')),
                  ButtonSegment(value: 'transport', label: Text('Transporte')),
                ],
                selected: {_kind},
                showSelectedIcon: false,
                onSelectionChanged: (v) => setState(() => _kind = v.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _concept,
                focusNode: _isService ? null : _focus.node,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Concepto',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _amount,
              focusNode: _isService ? _focus.node : null,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Monto',
                prefixText: '$currencySymbol ',
                helperText: s != null && s.defaultAmount > 0
                    ? 'Habitual: ${money(s.defaultAmount)}'
                    : null,
                border: const OutlineInputBorder(),
              ),
            ),
            if (_isService) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _period,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Período',
                  helperText: 'Mes que se paga, ej. Sep 2026',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            const SizedBox(height: 12),
            PaymentSourceField(onChanged: (v) => setState(() => _source = v)),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
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
              label: const Text('Registrar gasto'),
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Alta rápida de un servicio recurrente.
class _NewServiceSheet extends ConsumerStatefulWidget {
  const _NewServiceSheet();

  @override
  ConsumerState<_NewServiceSheet> createState() => _NewServiceSheetState();
}

class _NewServiceSheetState extends ConsumerState<_NewServiceSheet> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  late final SheetFocus _focus = SheetFocus(this);
  String _type = 'basico';
  bool _saving = false;

  static const _types = {
    'basico': 'Servicio básico',
    'externo': 'Servicio externo',
    'transporte': 'Transporte',
    'otro': 'Otro',
  };

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('El nombre es obligatorio.')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      final s = await ref
          .read(paymentsRepositoryProvider)
          .createService(
            name: _name.text.trim(),
            type: _type,
            defaultAmount: double.tryParse(_amount.text.replaceAll(',', '.')),
          );
      if (mounted) Navigator.pop(context, s);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Nuevo servicio recurrente',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              focusNode: _focus.node,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                hintText: 'Ej. Luz (CRE), Internet (Tigo)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _type,
              decoration: const InputDecoration(
                labelText: 'Tipo',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final e in _types.entries)
                  DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _type = v ?? _type),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Monto habitual (opcional)',
                prefixText: '$currencySymbol ',
                helperText: 'Se precarga al pagar; se puede cambiar cada vez.',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
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
              label: const Text('Guardar'),
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
