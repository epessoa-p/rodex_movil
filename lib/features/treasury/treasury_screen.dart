import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import 'treasury_account_screen.dart';
import 'treasury_repository.dart';

/// Tesorería (Finanzas): cuentas con sus saldos y saldo total. Desde aquí se
/// crean cuentas y se entra a cada una para registrar ingresos/gastos.
class TreasuryScreen extends ConsumerWidget {
  const TreasuryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider).me;
    final canManage = me?.can('treasury.manage') ?? false;
    final overview = ref.watch(treasuryAccountsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Tesorería')),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              onPressed: () => _newAccount(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nueva cuenta'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(treasuryAccountsProvider),
        child: overview.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(child: Text('$e', textAlign: TextAlign.center)),
            ],
          ),
          data: (o) => ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _TotalCard(total: o.totalBalance),
              const SizedBox(height: 16),
              Text('Cuentas',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (o.accounts.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text('Aún no hay cuentas. Crea la primera.',
                        style: TextStyle(color: Colors.black54)),
                  ),
                )
              else
                for (final a in o.accounts) _AccountTile(account: a),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _newAccount(BuildContext context, WidgetRef ref) async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _NewAccountSheet(),
    );
    if (created == true) ref.invalidate(treasuryAccountsProvider);
  }
}

class _TotalCard extends StatelessWidget {
  final double total;
  const _TotalCard({required this.total});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.teal.withValues(alpha: .10),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            const CircleAvatar(
              backgroundColor: Colors.teal,
              child: Icon(Icons.account_balance, color: Colors.white),
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text('Saldo total',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            ),
            Text(money(total),
                style: const TextStyle(
                    fontSize: 20, fontWeight: FontWeight.w800)),
          ],
        ),
      ),
    );
  }
}

class _AccountTile extends StatelessWidget {
  final TreasuryAccount account;
  const _AccountTile({required this.account});

  @override
  Widget build(BuildContext context) {
    final isBank = account.type == 'bank';
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor:
              (isBank ? Colors.indigo : Colors.green).withValues(alpha: .15),
          child: Icon(isBank ? Icons.account_balance : Icons.payments_outlined,
              color: isBank ? Colors.indigo : Colors.green),
        ),
        title: Text(account.name,
            style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text([
          account.typeLabel,
          if (account.bankName != null && account.bankName!.isNotEmpty)
            account.bankName,
          if (!account.active) '(inactiva)',
        ].whereType<String>().join(' · ')),
        trailing: Text(money(account.balance),
            style: const TextStyle(fontWeight: FontWeight.w800)),
        onTap: () => Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => TreasuryAccountScreen(accountId: account.id),
        )),
      ),
    );
  }
}

/// Formulario de alta de cuenta (bottom sheet).
class _NewAccountSheet extends ConsumerStatefulWidget {
  const _NewAccountSheet();

  @override
  ConsumerState<_NewAccountSheet> createState() => _NewAccountSheetState();
}

class _NewAccountSheetState extends ConsumerState<_NewAccountSheet> {
  final _name = TextEditingController();
  final _bank = TextEditingController();
  final _number = TextEditingController();
  final _opening = TextEditingController();
  String _type = 'cash';
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _bank.dispose();
    _number.dispose();
    _opening.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _snack('El nombre es obligatorio.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(treasuryRepositoryProvider).createAccount(
            name: _name.text.trim(),
            type: _type,
            bankName: _bank.text.trim().isEmpty ? null : _bank.text.trim(),
            accountNumber:
                _number.text.trim().isEmpty ? null : _number.text.trim(),
            openingBalance:
                double.tryParse(_opening.text.replaceAll(',', '.')),
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
    final isBank = _type == 'bank';
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
          const Text('Nueva cuenta',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                  value: 'cash',
                  label: Text('Efectivo'),
                  icon: Icon(Icons.payments_outlined)),
              ButtonSegment(
                  value: 'bank',
                  label: Text('Banco'),
                  icon: Icon(Icons.account_balance)),
            ],
            selected: {_type},
            onSelectionChanged: (s) => setState(() => _type = s.first),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _name,
            decoration: const InputDecoration(
                labelText: 'Nombre *', border: OutlineInputBorder()),
          ),
          if (isBank) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _bank,
              decoration: const InputDecoration(
                  labelText: 'Banco', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _number,
              decoration: const InputDecoration(
                  labelText: 'N° de cuenta', border: OutlineInputBorder()),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _opening,
            keyboardType:
                const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
                labelText: 'Saldo de apertura (opcional)',
                prefixText: '$currencySymbol ',
                border: const OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: const Text('Crear cuenta'),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
