import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/app_toast.dart';
import '../../core/format.dart';
import '../../core/sheet_focus.dart';
import '../pos/pos_repository.dart' show cashSessionProvider;
import '../treasury/treasury_repository.dart' show treasuryAccountsProvider;
import 'payments_repository.dart';
import 'widgets/payment_source_field.dart';

/// Tab Personal (Pagos): personal activo con su último pago; tocar abre la hoja
/// para pagar sueldo/adelanto con período y origen Caja/Tesorería.
class PersonalTab extends ConsumerWidget {
  const PersonalTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(expensesOverviewProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(expensesOverviewProvider.future),
      child: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ListView(
          children: [
            const SizedBox(height: 80),
            Center(child: Text('$e', textAlign: TextAlign.center)),
          ],
        ),
        data: (o) => o.personal.isEmpty
            ? ListView(
                children: const [
                  SizedBox(height: 120),
                  Icon(Icons.badge_outlined, size: 56, color: Colors.black26),
                  SizedBox(height: 12),
                  Center(child: Text('No hay personal activo registrado.')),
                ],
              )
            : ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  _MonthHeader(
                    label: 'Pagado al personal este mes',
                    amount: o.payrollMonthTotal,
                    icon: Icons.badge_outlined,
                    color: Colors.indigo,
                  ),
                  const SizedBox(height: 8),
                  for (final p in o.personal)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: Colors.indigo.withValues(alpha: .12),
                          child: Text(
                            p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                            style: const TextStyle(
                              color: Colors.indigo,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        title: Text(
                          p.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          p.lastPayment == null
                              ? '${p.cargo ?? 'Sin cargo'} · sin pagos registrados'
                              : '${p.cargo ?? 'Sin cargo'} · último: ${money(p.lastPayment!.amount)}'
                                    '${p.lastPayment!.period != null ? ' (${p.lastPayment!.period})' : ''}'
                                    ' el ${p.lastPayment!.date}',
                          style: const TextStyle(fontSize: 12),
                        ),
                        trailing: const Icon(
                          Icons.payments_outlined,
                          color: Colors.indigo,
                        ),
                        onTap: () => _pay(context, ref, p),
                      ),
                    ),
                ],
              ),
      ),
    );
  }

  Future<void> _pay(BuildContext context, WidgetRef ref, PersonalRow p) async {
    final done = await showModalBottomSheet<ExpenseMovement>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PayrollSheet(person: p),
    );
    if (done != null && context.mounted) {
      ref.invalidate(expensesOverviewProvider);
      ref.invalidate(cashSessionProvider);
      ref.invalidate(treasuryAccountsProvider);
      AppToast.success(
        context,
        'Pago a ${p.name} registrado: ${money(done.amount)}',
      );
    }
  }
}

/// Encabezado de total del mes (compartido con Gastos).
class _MonthHeader extends StatelessWidget {
  final String label;
  final double amount;
  final IconData icon;
  final Color color;
  const _MonthHeader({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) => Card(
    color: color.withValues(alpha: .08),
    child: ListTile(
      leading: Icon(icon, color: color),
      title: Text(
        label,
        style: const TextStyle(fontSize: 12, color: Colors.black54),
      ),
      trailing: Text(
        money(amount),
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    ),
  );
}

/// Hoja de pago a personal: monto, período, origen y notas.
class _PayrollSheet extends ConsumerStatefulWidget {
  final PersonalRow person;
  const _PayrollSheet({required this.person});

  @override
  ConsumerState<_PayrollSheet> createState() => _PayrollSheetState();
}

/// Períodos de pago a personal: los mismos valores que el select de la web,
/// porque van dentro de la descripción del movimiento ("Pago a personal (Quincena) · …").
const _periodOptions = ['Día', 'Semana', 'Quincena', 'Mes', 'Otro'];

class _PayrollSheetState extends ConsumerState<_PayrollSheet> {
  final _amount = TextEditingController();
  late final SheetFocus _focus = SheetFocus(this);
  final _otherPeriod = TextEditingController(); // solo si el período es "Otro"
  final _notes = TextEditingController();
  String _period = 'Mes';
  PaymentSource? _source = const PaymentSource.cash();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final last = widget.person.lastPayment;
    if (last != null) {
      // Sugerir el mismo monto y el mismo período del último pago.
      final v = last.amount;
      _amount.text = v == v.roundToDouble()
          ? v.toStringAsFixed(0)
          : v.toStringAsFixed(2);
      if (last.period != null) {
        if (_periodOptions.contains(last.period)) {
          _period = last.period!;
        } else {
          _period = 'Otro';
          _otherPeriod.text = last.period!;
        }
      }
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _focus.dispose();
    _otherPeriod.dispose();
    _notes.dispose();
    super.dispose();
  }

  /// Texto que viaja como `period`: la opción, o lo escrito si es "Otro".
  String get _periodValue {
    if (_period != 'Otro') return _period;
    final custom = _otherPeriod.text.trim();
    return custom.isEmpty ? 'Otro' : custom;
  }

  Future<void> _submit() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) return _snack('Ingresa un monto mayor a cero.');
    final source = _source;
    if (source == null) return _snack('Selecciona la cuenta de tesorería.');

    setState(() => _saving = true);
    try {
      final m = await ref
          .read(paymentsRepositoryProvider)
          .registerExpense(
            kind: 'payroll',
            amount: amount,
            source: source.source,
            personalId: widget.person.id,
            period: _periodValue,
            treasuryAccountId: source.treasuryAccountId,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (mounted) Navigator.pop(context, m);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.apiError(context, e);
      }
    }
  }

  void _snack(String m) =>
      AppToast.error(context, m, title: 'Revisa el formulario');

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
            Text(
              'Pagar a ${widget.person.name}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            if (widget.person.cargo != null)
              Text(
                widget.person.cargo!,
                style: const TextStyle(color: Colors.black54),
              ),
            const SizedBox(height: 16),
            TextField(
              controller: _amount,
              focusNode: _focus.node,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Monto',
                prefixText: '$currencySymbol ',
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            const Text(
              'Período',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            // Selección fija (igual que la web): Día / Semana / Quincena / Mes / Otro.
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final p in _periodOptions)
                  ChoiceChip(
                    label: Text(p),
                    selected: _period == p,
                    onSelected: (_) => setState(() => _period = p),
                  ),
              ],
            ),
            if (_period == 'Otro') ...[
              const SizedBox(height: 10),
              TextField(
                controller: _otherPeriod,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: '¿Qué se paga?',
                  hintText: 'Ej.: Bono, Adelanto, Aguinaldo',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: 12),
            PaymentSourceField(onChanged: (s) => setState(() => _source = s)),
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
              label: const Text('Confirmar pago'),
              onPressed: _saving ? null : _submit,
            ),
          ],
        ),
      ),
    );
  }
}
