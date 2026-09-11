import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api_client.dart';
import '../../../core/format.dart';
import '../../../core/providers.dart';
import '../../treasury/treasury_repository.dart';

/// Origen del pago elegido: 'cash' (caja abierta) o 'treasury' + cuenta.
class PaymentSource {
  final String source; // cash | treasury
  final int? treasuryAccountId;
  const PaymentSource.cash() : source = 'cash', treasuryAccountId = null;
  const PaymentSource.treasury(int accountId)
    : source = 'treasury',
      treasuryAccountId = accountId;

  bool get isTreasury => source == 'treasury';
}

/// Selector Caja / Tesorería con desplegable de cuentas. Solo ofrece Tesorería
/// si el usuario tiene `treasury.view`; carga las cuentas él mismo.
/// Notifica el origen elegido por [onChanged] (null = tesorería sin cuenta).
class PaymentSourceField extends ConsumerStatefulWidget {
  final ValueChanged<PaymentSource?> onChanged;
  const PaymentSourceField({super.key, required this.onChanged});

  @override
  ConsumerState<PaymentSourceField> createState() => _PaymentSourceFieldState();
}

class _PaymentSourceFieldState extends ConsumerState<PaymentSourceField> {
  String _source = 'cash';
  int? _accountId;
  List<TreasuryAccount> _accounts = [];
  bool _loading = false;

  bool get _canTreasury =>
      ref.read(authControllerProvider).me?.can('treasury.view') ?? false;

  @override
  void initState() {
    super.initState();
    // NO llamar a widget.onChanged aquí: haría setState en la hoja padre
    // mientras se está construyendo ("setState() called during build", que
    // en el celular se manifestó como congelamiento). Las hojas ya arrancan
    // con PaymentSource.cash(); solo se notifica cuando el usuario cambia algo.
    if (_canTreasury) _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    setState(() => _loading = true);
    try {
      final accounts =
          (await ref.read(treasuryRepositoryProvider).accounts()).accounts;
      if (mounted) {
        setState(() {
          _accounts = accounts;
          _accountId = accounts.isNotEmpty ? accounts.first.id : null;
          _loading = false;
        });
      }
    } on ApiException {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _emit() {
    if (_source == 'cash') {
      widget.onChanged(const PaymentSource.cash());
    } else {
      widget.onChanged(
        _accountId == null ? null : PaymentSource.treasury(_accountId!),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_canTreasury) {
      return const Text(
        'Saldrá como gasto de tu caja abierta.',
        style: TextStyle(color: Colors.black54, fontSize: 12),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
          onSelectionChanged: (s) {
            setState(() => _source = s.first);
            _emit();
          },
        ),
        if (_source == 'treasury') ...[
          const SizedBox(height: 12),
          if (_loading)
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
              onChanged: (v) {
                setState(() => _accountId = v);
                _emit();
              },
            ),
        ],
        const SizedBox(height: 6),
        Text(
          _source == 'treasury'
              ? 'Se descontará de la cuenta seleccionada.'
              : 'Saldrá como gasto de tu caja abierta.',
          style: const TextStyle(color: Colors.black54, fontSize: 12),
        ),
      ],
    );
  }
}
