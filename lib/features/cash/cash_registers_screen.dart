import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/app_toast.dart';
import '../../core/upper_case.dart';
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
    setState(() {
      _loading = true;
      _error = null;
    });
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
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  Future<void> _openForm({CashRegisterAdmin? editing}) async {
    final form = _form;
    if (form == null) return;
    if (form.branches.isEmpty || form.personal.isEmpty) {
      _snack('Primero crea una sucursal y registra personal (desde la web).');
      return;
    }
    // Con registros (sesiones/movimientos) la caja queda congelada.
    if (editing != null && editing.hasRecords) {
      AppToast.info(
        context,
        '«${editing.name}» ya tiene sesiones o movimientos registrados. '
        'Si necesitas cambiarla, crea otra caja.',
        title: 'Caja no editable',
      );
      return;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CashRegisterForm(form: form, editing: editing),
    );
    if (saved == true) _load();
  }

  // Validaciones y errores locales: toast rojo arriba (visible sobre hojas).
  void _snack(String m) => AppToast.error(context, m);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Cajas')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-cash-registers',
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
                  ? ListView(
                      children: const [
                        SizedBox(height: 120),
                        Icon(
                          Icons.point_of_sale_outlined,
                          size: 56,
                          color: Colors.black26,
                        ),
                        SizedBox(height: 12),
                        Center(
                          child: Text(
                            'Sin cajas. Crea una y asígnala a un personal.',
                          ),
                        ),
                      ],
                    )
                  : ListView.separated(
                      itemCount: _items.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final r = _items[i];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor:
                                (r.active ? Colors.green : Colors.grey)
                                    .withValues(alpha: .12),
                            child: Icon(
                              Icons.point_of_sale,
                              color: r.active ? Colors.green : Colors.grey,
                            ),
                          ),
                          title: Text(r.name),
                          subtitle: Text(
                            [
                              r.branch ?? 'Sin sucursal',
                              'Personal: ${r.personal ?? '—'}',
                            ].join('  ·  '),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (r.hasSession)
                                const Chip(
                                  label: Text('En uso'),
                                  visualDensity: VisualDensity.compact,
                                )
                              else if (!r.active)
                                const Text(
                                  'Inactiva',
                                  style: TextStyle(color: Colors.grey),
                                ),
                              if (r.hasRecords)
                                const Padding(
                                  padding: EdgeInsets.only(left: 6),
                                  child: Tooltip(
                                    message: 'Con registros: no editable',
                                    child: Icon(
                                      Icons.lock_outline,
                                      size: 18,
                                      color: Colors.black38,
                                    ),
                                  ),
                                ),
                            ],
                          ),
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

  /// Sucursales elegibles para el personal elegido: donde aún no tiene caja
  /// (una caja por sucursal POR PERSONAL), más la propia cuando se edita.
  List<NamedOption> get _branches => widget.form.freeBranchesFor(
    _personalId,
    exceptRegisterId: widget.editing?.id,
  );

  @override
  void initState() {
    super.initState();
    final e = widget.editing;
    _name = TextEditingController(text: e?.name ?? '');
    _personalId = e?.personalId ?? widget.form.personal.first.id;
    _branchId = e?.branchId ?? _firstFree();
    _active = e?.active ?? true;
  }

  int? _firstFree() {
    final free = _branches;
    return free.isNotEmpty ? free.first.id : null;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      AppToast.error(context, 'El nombre es obligatorio.');
      return;
    }
    if (_branchId == null) {
      AppToast.error(context, 'Selecciona una sucursal.');
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
        AppToast.apiError(context, err);
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
          Text(
            widget.editing == null ? 'Nueva caja' : 'Editar caja',
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          TextField(
            textCapitalization: TextCapitalization.characters,
            inputFormatters: upperCaseFormatters,
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Nombre de la caja',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 12),
          // La lista depende del personal: se re-crea al cambiarlo (key) para
          // que el valor inicial siempre exista entre los ítems.
          DropdownButtonFormField<int>(
            key: ValueKey('branch-$_personalId'),
            initialValue: _branchId,
            decoration: InputDecoration(
              labelText: 'Sucursal',
              border: const OutlineInputBorder(),
              helperText: _branches.isEmpty
                  ? 'Este personal ya tiene caja en todas las sucursales.'
                  : 'Una caja por sucursal por personal',
              helperStyle: _branches.isEmpty
                  ? const TextStyle(color: Colors.red)
                  : null,
            ),
            items: [
              for (final b in _branches)
                DropdownMenuItem(value: b.id, child: Text(b.name)),
            ],
            onChanged: (v) => setState(() => _branchId = v),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<int>(
            initialValue: _personalId,
            decoration: const InputDecoration(
              labelText: 'Asignar a personal',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final p in widget.form.personal)
                DropdownMenuItem(value: p.id, child: Text(p.name)),
            ],
            onChanged: (v) => setState(() {
              _personalId = v;
              // Si la sucursal elegida ya está ocupada por este personal, se
              // salta a la primera libre.
              if (!_branches.any((b) => b.id == _branchId)) {
                _branchId = _firstFree();
              }
            }),
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
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
