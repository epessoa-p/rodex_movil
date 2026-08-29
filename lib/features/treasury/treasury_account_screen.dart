import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import 'treasury_repository.dart';

/// Detalle de una cuenta de tesorería: saldo, botones de Ingreso/Gasto y el
/// historial de movimientos.
class TreasuryAccountScreen extends ConsumerWidget {
  final int accountId;
  const TreasuryAccountScreen({super.key, required this.accountId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider).me;
    final canManage = me?.can('treasury.manage') ?? false;
    final detail = ref.watch(treasuryAccountProvider(accountId));

    return Scaffold(
      appBar: AppBar(title: Text(detail.valueOrNull?.account.name ?? 'Cuenta')),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(treasuryAccountProvider(accountId)),
        child: detail.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(child: Text('$e', textAlign: TextAlign.center)),
            ],
          ),
          data: (d) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _BalanceCard(account: d.account),
              if (canManage) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.green,
                            minimumSize: const Size.fromHeight(48)),
                        icon: const Icon(Icons.arrow_downward),
                        label: const Text('Ingreso'),
                        onPressed: () =>
                            _movement(context, ref, d.account, income: true),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            minimumSize: const Size.fromHeight(48)),
                        icon: const Icon(Icons.arrow_upward),
                        label: const Text('Gasto'),
                        onPressed: () =>
                            _movement(context, ref, d.account, income: false),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 20),
              Text('Movimientos',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (d.movements.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Sin movimientos todavía.',
                        style: TextStyle(color: Colors.black54)),
                  ),
                )
              else
                for (final m in d.movements) _MovementTile(movement: m),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _movement(
    BuildContext context,
    WidgetRef ref,
    TreasuryAccount account, {
    required bool income,
  }) async {
    final ok = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MovementSheet(account: account, income: income),
    );
    if (ok == true) ref.invalidate(treasuryAccountProvider(accountId));
  }
}

class _BalanceCard extends StatelessWidget {
  final TreasuryAccount account;
  const _BalanceCard({required this.account});

  @override
  Widget build(BuildContext context) {
    final isBank = account.type == 'bank';
    return Card(
      color: Colors.teal.withValues(alpha: .10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: isBank ? Colors.indigo : Colors.green,
                  child: Icon(
                      isBank
                          ? Icons.account_balance
                          : Icons.payments_outlined,
                      color: Colors.white),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(account.typeLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 13)),
                      if (account.bankName != null &&
                          account.bankName!.isNotEmpty)
                        Text(account.bankName!,
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 12)),
                      if (account.accountNumber != null &&
                          account.accountNumber!.isNotEmpty)
                        Text(account.accountNumber!,
                            style: const TextStyle(
                                color: Colors.black54, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Saldo disponible',
                style: TextStyle(color: Colors.black54, fontSize: 13)),
            Text(money(account.balance),
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _MovementTile extends StatelessWidget {
  final TreasuryMovement movement;
  const _MovementTile({required this.movement});

  @override
  Widget build(BuildContext context) {
    final income = movement.isIncome;
    return Card(
      child: ListTile(
        dense: true,
        leading: CircleAvatar(
          backgroundColor:
              (income ? Colors.green : Colors.red).withValues(alpha: .15),
          child: Icon(income ? Icons.arrow_downward : Icons.arrow_upward,
              color: income ? Colors.green : Colors.red, size: 20),
        ),
        title: Text(movement.categoryLabel,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([
          if (movement.description != null && movement.description!.isNotEmpty)
            movement.description,
          if (movement.date != null) _fmt(movement.date!),
          if (movement.user != null) movement.user,
        ].whereType<String>().join(' · ')),
        trailing: Text('${income ? '+' : '-'}${money(movement.amount)}',
            style: TextStyle(
                fontWeight: FontWeight.w800,
                color: income ? Colors.green : Colors.red)),
      ),
    );
  }

  String _fmt(String iso) {
    final d = DateTime.tryParse(iso)?.toLocal();
    if (d == null) return '';
    return '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
  }
}

/// Hoja para registrar un ingreso o gasto en la cuenta.
class _MovementSheet extends ConsumerStatefulWidget {
  final TreasuryAccount account;
  final bool income;
  const _MovementSheet({required this.account, required this.income});

  @override
  ConsumerState<_MovementSheet> createState() => _MovementSheetState();
}

class _MovementSheetState extends ConsumerState<_MovementSheet> {
  final _amount = TextEditingController();
  final _desc = TextEditingController();
  late String _category = widget.income ? 'capital_injection' : 'expense';
  bool _saving = false;

  // Categorías por tipo (coinciden con el backend).
  static const _incomeCats = {
    'capital_injection': 'Aporte de capital',
    'adjustment_in': 'Ajuste positivo',
  };
  static const _expenseCats = {
    'expense': 'Gasto',
    'adjustment_out': 'Ajuste negativo',
  };

  @override
  void dispose() {
    _amount.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final amount = double.tryParse(_amount.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) {
      _snack('Ingresa un monto válido.');
      return;
    }
    if (!widget.income && amount > widget.account.balance) {
      _snack('El monto supera el saldo disponible.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(treasuryRepositoryProvider).addMovement(
            widget.account.id,
            category: _category,
            amount: amount,
            description: _desc.text.trim().isEmpty ? null : _desc.text.trim(),
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
    final cats = widget.income ? _incomeCats : _expenseCats;
    final color = widget.income ? Colors.green : Colors.red;
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
          Text(widget.income ? 'Nuevo ingreso' : 'Nuevo gasto',
              style: TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w700, color: color)),
          Text('${widget.account.name} · Saldo ${money(widget.account.balance)}',
              style: const TextStyle(color: Colors.black54, fontSize: 13)),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            initialValue: _category,
            decoration: const InputDecoration(
                labelText: 'Concepto', border: OutlineInputBorder()),
            items: [
              for (final e in cats.entries)
                DropdownMenuItem(value: e.key, child: Text(e.value)),
            ],
            onChanged: (v) => setState(() => _category = v ?? _category),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _amount,
            autofocus: true,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: 'Monto',
                prefixText: '$currencySymbol ',
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            minLines: 1,
            maxLines: 3,
            decoration: const InputDecoration(
                labelText: 'Descripción (opcional)',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style: FilledButton.styleFrom(
                backgroundColor: color,
                minimumSize: const Size.fromHeight(48)),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: Text(widget.income ? 'Registrar ingreso' : 'Registrar gasto'),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
