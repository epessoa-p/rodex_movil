import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../pos/pos_repository.dart';

class CashScreen extends ConsumerWidget {
  const CashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(cashSessionProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Caja')),
      body: session.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (s) => s == null
            ? const _OpenCashForm()
            : _OpenSessionView(session: s),
      ),
    );
  }
}

/// Categorías de gasto simples soportadas por el móvil.
const _expenseCategories = <String, String>{
  'expense_operational': 'Operativo',
  'expense_service': 'Servicio',
  'expense_transport': 'Transporte',
};

class _OpenSessionView extends ConsumerStatefulWidget {
  final CashSession session;
  const _OpenSessionView({required this.session});

  @override
  ConsumerState<_OpenSessionView> createState() => _OpenSessionViewState();
}

class _OpenSessionViewState extends ConsumerState<_OpenSessionView> {
  Future<List<CashMovement>>? _movements;

  @override
  void initState() {
    super.initState();
    _reloadMovements();
  }

  void _reloadMovements() {
    setState(() {
      _movements = ref.read(posRepositoryProvider).sessionMovements();
    });
  }

  CashSession get session => widget.session;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(cashSessionProvider);
        _reloadMovements();
      },
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Caja abierta',
                      style:
                          TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                  const SizedBox(height: 8),
                  _row('Caja', session.cashRegister ?? '-'),
                  _row('Sucursal', session.branch ?? '-'),
                  const Divider(),
                  _row('Monto inicial', money(session.openingAmount)),
                  _row('Ingresos', '+ ${money(session.totalIncome)}',
                      color: Colors.green),
                  _row('Gastos', '- ${money(session.totalExpense)}',
                      color: Colors.red),
                  const Divider(),
                  _row('Esperado en caja', money(session.expectedAmount),
                      bold: true),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(46)),
                  icon: const Icon(Icons.remove_circle_outline),
                  label: const Text('Registrar gasto'),
                  onPressed: _expenseDialog,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      minimumSize: const Size.fromHeight(46)),
                  icon: const Icon(Icons.lock_outline),
                  label: const Text('Cerrar caja'),
                  onPressed: _closeDialog,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Text('Movimientos',
              style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          _MovementsList(future: _movements),
        ],
      ),
    );
  }

  Widget _row(String k, String v,
          {bool bold = false, Color? color}) =>
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k, style: const TextStyle(color: Colors.black54)),
            Text(v,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
                    fontSize: bold ? 16 : null,
                    color: color)),
          ],
        ),
      );

  Future<void> _expenseDialog() async {
    final amountCtrl = TextEditingController();
    final conceptCtrl = TextEditingController();
    String category = 'expense_operational';

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) => AlertDialog(
          title: const Text('Registrar gasto'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amountCtrl,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                    labelText: 'Monto', prefixText: '$currencySymbol '),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: category,
                decoration: const InputDecoration(labelText: 'Tipo'),
                items: [
                  for (final e in _expenseCategories.entries)
                    DropdownMenuItem(value: e.key, child: Text(e.value)),
                ],
                onChanged: (v) => setLocal(() => category = v ?? category),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: conceptCtrl,
                decoration: const InputDecoration(
                    labelText: 'Concepto (opcional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Registrar')),
          ],
        ),
      ),
    );

    if (ok != true) return;
    final amount = double.tryParse(amountCtrl.text.replaceAll(',', '.')) ?? 0;
    if (amount <= 0) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Ingresa un monto válido.')));
      }
      return;
    }

    try {
      await ref.read(posRepositoryProvider).registerExpense(
            amount: amount,
            category: category,
            concept: conceptCtrl.text.trim().isEmpty
                ? null
                : conceptCtrl.text.trim(),
          );
      ref.invalidate(cashSessionProvider);
      _reloadMovements();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gasto registrado.')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  Future<void> _closeDialog() async {
    final controller =
        TextEditingController(text: session.expectedAmount.toStringAsFixed(2));
    final amount = await showDialog<double>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setLocal) {
          final counted =
              double.tryParse(controller.text.replaceAll(',', '.')) ?? 0;
          final diff = counted - session.expectedAmount;
          return AlertDialog(
            title: const Text('Cerrar caja'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _row('Esperado', money(session.expectedAmount)),
                const SizedBox(height: 8),
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setLocal(() {}),
                  decoration: InputDecoration(
                      labelText: 'Monto contado en caja',
                      prefixText: '$currencySymbol '),
                ),
                const SizedBox(height: 8),
                _row(
                  'Diferencia',
                  '${diff >= 0 ? '+' : ''}${money(diff)}',
                  bold: true,
                  color: diff == 0
                      ? Colors.green
                      : (diff > 0 ? Colors.blue : Colors.red),
                ),
              ],
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancelar')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, counted),
                child: const Text('Cerrar'),
              ),
            ],
          );
        },
      ),
    );
    if (amount == null) return;
    try {
      await ref.read(posRepositoryProvider).closeSession(closingAmount: amount);
      ref.invalidate(cashSessionProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Caja cerrada.')));
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _MovementsList extends StatelessWidget {
  final Future<List<CashMovement>>? future;
  const _MovementsList({required this.future});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<CashMovement>>(
      future: future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }
        if (snap.hasError) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Text('No se pudieron cargar los movimientos.\n${snap.error}',
                style: const TextStyle(color: Colors.black54)),
          );
        }
        final items = snap.data ?? [];
        if (items.isEmpty) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(
                child: Text('Aún no hay movimientos en esta caja.',
                    style: TextStyle(color: Colors.black54))),
          );
        }
        return Column(
          children: [
            for (final m in items)
              Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  dense: true,
                  leading: CircleAvatar(
                    backgroundColor:
                        (m.isExpense ? Colors.red : Colors.green)
                            .withValues(alpha: .12),
                    child: Icon(
                        m.isExpense
                            ? Icons.arrow_upward
                            : Icons.arrow_downward,
                        color: m.isExpense ? Colors.red : Colors.green,
                        size: 18),
                  ),
                  title: Text(m.description?.isNotEmpty == true
                      ? m.description!
                      : m.category),
                  subtitle: Text(m.category),
                  trailing: Text(
                    '${m.isExpense ? '-' : '+'} ${money(m.amount)}',
                    style: TextStyle(
                        fontWeight: FontWeight.w700,
                        color: m.isExpense ? Colors.red : Colors.green),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _OpenCashForm extends ConsumerStatefulWidget {
  const _OpenCashForm();

  @override
  ConsumerState<_OpenCashForm> createState() => _OpenCashFormState();
}

class _OpenCashFormState extends ConsumerState<_OpenCashForm> {
  List<CashRegisterOption>? _registers;
  int? _selected;
  final _amount = TextEditingController(text: '0');
  bool _loading = true;
  bool _submitting = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final regs = await ref.read(posRepositoryProvider).registers();
      setState(() {
        _registers = regs;
        _selected = regs.where((r) => !r.hasSession).firstOrNull?.id;
        _loading = false;
      });
    } on ApiException catch (e) {
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _open() async {
    if (_selected == null) return;
    setState(() => _submitting = true);
    try {
      await ref.read(posRepositoryProvider).openSession(
            cashRegisterId: _selected!,
            openingAmount: double.tryParse(_amount.text) ?? 0,
          );
      ref.invalidate(cashSessionProvider);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!));

    final registers = _registers ?? [];
    final available = registers.where((r) => !r.hasSession).toList();

    if (registers.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No tienes una caja asignada. Pide al administrador que te asigne una.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Abrir caja',
            style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
        const SizedBox(height: 12),
        for (final r in registers)
          Card(
            child: ListTile(
              enabled: !r.hasSession,
              leading: Icon(
                _selected == r.id
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: _selected == r.id
                    ? Theme.of(context).colorScheme.primary
                    : null,
              ),
              title: Text(r.name),
              subtitle: Text(r.hasSession
                  ? 'Ya tiene una sesión abierta'
                  : (r.branch ?? '')),
              onTap: r.hasSession
                  ? null
                  : () => setState(() => _selected = r.id),
            ),
          ),
        const SizedBox(height: 8),
        TextField(
          controller: _amount,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
              labelText: 'Monto inicial', prefixText: '$currencySymbol '),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          icon: const Icon(Icons.lock_open_outlined),
          label: const Text('Abrir caja'),
          onPressed: (_submitting || available.isEmpty || _selected == null)
              ? null
              : _open,
        ),
      ],
    );
  }
}
