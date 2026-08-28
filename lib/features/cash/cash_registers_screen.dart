import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'cash_admin_repository.dart';

/// Administración de cajas: crear una caja y asignarla a un personal
/// (requisito para que ese personal pueda abrir caja y vender).
class CashRegistersScreen extends ConsumerStatefulWidget {
  const CashRegistersScreen({super.key});

  @override
  ConsumerState<CashRegistersScreen> createState() =>
      _CashRegistersScreenState();
}

class _CashRegistersScreenState extends ConsumerState<CashRegistersScreen> {
  List<CashRegisterAdmin> _items = [];
  CashRegisterFormData? _form;
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final repo = ref.read(cashAdminRepositoryProvider);
      final results = await Future.wait([repo.registers(), repo.formData()]);
      if (mounted) {
        setState(() {
          _items = results[0] as List<CashRegisterAdmin>;
          _form = results[1] as CashRegisterFormData;
          _loading = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _openForm({CashRegisterAdmin? editing}) async {
    final form = _form;
    if (form == null) return;
    if (form.branches.isEmpty || form.personal.isEmpty) {
      _snack('Primero crea una sucursal y registra personal (desde la web).');
      return;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CashRegisterForm(form: form, editing: editing),
    );
    if (saved == true) _load();
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cajas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openForm(),
        icon: const Icon(Icons.add),
        label: const Text('Nueva caja'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text('$_error', textAlign: TextAlign.center),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: _items.isEmpty
                      ? ListView(children: const [
                          SizedBox(height: 120),
                          Icon(Icons.point_of_sale_outlined,
                              size: 56, color: Colors.black26),
                          SizedBox(height: 12),
                          Center(
                              child: Text(
                                  'Sin cajas. Crea una y asígnala a un personal.')),
                        ])
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final r = _items[i];
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: (r.active
                                        ? Colors.green
                                        : Colors.grey)
                                    .withValues(alpha: .12),
                                child: Icon(Icons.point_of_sale,
                                    color:
                                        r.active ? Colors.green : Colors.grey),
                              ),
                              title: Text(r.name),
                              subtitle: Text([
                                r.branch ?? 'Sin sucursal',
                                'Personal: ${r.personal ?? '—'}',
                              ].join('  ·  ')),
                              trailing: r.hasSession
                                  ? const Chip(
                                      label: Text('En uso'),
                                      visualDensity: VisualDensity.compact)
                                  : (r.active
                                      ? null
                                      : const Text('Inactiva',
                                          style:
                                              TextStyle(color: Colors.grey))),
                              onTap: () => _openForm(editing: r),
                            );
                          },
                        ),
                ),
    );
  }
}

class _CashRegisterForm extends ConsumerStatefulWidget {
  final CashRegisterFormData form;
  final CashRegisterAdmin? editing;
  const _CashRegisterForm({required this.form, this.editing});

  @override
  ConsumerState<_CashRegisterForm> createState() => _CashRegisterFormState();
}

class _CashRegisterFormState extends ConsumerState<_CashRegisterForm> {
  late final TextEditingController _name;
  int? _branchId;
  int? _personalId;
  bool _active = true;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _name = TextEditingController(text: e?.name ?? '');
    _branchId = e?.branchId ?? widget.form.branches.first.id;
    _personalId = e?.personalId ?? widget.form.personal.first.id;
    _active = e?.active ?? true;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('El nombre es obligatorio.')));
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(cashAdminRepositoryProvider);
      final e = widget.editing;
      if (e == null) {
        await repo.create(
          branchId: _branchId!,
          name: _name.text.trim(),
          assignedPersonalId: _personalId!,
          active: _active,
        );
      } else {
        await repo.update(
          e.id,
          branchId: _branchId!,
          name: _name.text.trim(),
          assignedPersonalId: _personalId!,
          active: _active,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (err) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(err.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.editing == null ? 'Nueva caja' : 'Editar caja',
              style:
                  const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Nombre de la caja', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _branchId,
            decoration: const InputDecoration(
                labelText: 'Sucursal', border: OutlineInputBorder()),
            items: [
              for (final b in widget.form.branches)
                DropdownMenuItem(value: b.id, child: Text(b.name)),
            ],
            onChanged: (v) => setState(() => _branchId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _personalId,
            decoration: const InputDecoration(
                labelText: 'Asignar a personal',
                border: OutlineInputBorder()),
            items: [
              for (final p in widget.form.personal)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() => _personalId = v),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Activa'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 8),
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
            label: const Text('Guardar'),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
