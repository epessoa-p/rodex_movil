import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import 'workshop_repository.dart';

/// Administración de mecánicos: listado + alta/edición con todos los campos.
class MechanicsScreen extends ConsumerWidget {
  const MechanicsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider).me;
    final canCreate = me?.can('mechanics.create') ?? false;
    final canEdit = me?.can('mechanics.edit') ?? false;
    final async = ref.watch(mechanicsFullProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mecánicos')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(context, ref),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo mecánico'),
            )
          : null,
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(mechanicsFullProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 80),
            Center(child: Text('$e', textAlign: TextAlign.center)),
          ]),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 80),
                Center(child: Text('Aún no hay mecánicos. Crea el primero.')),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final m = list[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor:
                          (m.active ? Colors.deepPurple : Colors.grey)
                              .withValues(alpha: .15),
                      child: Icon(Icons.engineering_outlined,
                          color: m.active ? Colors.deepPurple : Colors.grey),
                    ),
                    title: Text(m.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text([
                      if (m.specialty != null && m.specialty!.isNotEmpty)
                        m.specialty,
                      if (m.phone != null && m.phone!.isNotEmpty) m.phone,
                      '${_trim(m.commissionRate)}% comisión',
                      if (!m.active) 'inactivo',
                    ].whereType<String>().join(' · ')),
                    trailing: canEdit ? const Icon(Icons.chevron_right) : null,
                    onTap: canEdit ? () => _openForm(context, ref, edit: m) : null,
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  Future<void> _openForm(BuildContext context, WidgetRef ref,
      {MechanicFull? edit}) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => MechanicFormScreen(edit: edit),
    ));
    if (saved == true) ref.invalidate(mechanicsFullProvider);
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// Formulario de alta/edición de mecánico (todos los campos).
class MechanicFormScreen extends ConsumerStatefulWidget {
  final MechanicFull? edit;
  const MechanicFormScreen({super.key, this.edit});

  @override
  ConsumerState<MechanicFormScreen> createState() => _MechanicFormScreenState();
}

class _MechanicFormScreenState extends ConsumerState<MechanicFormScreen> {
  late final _name = TextEditingController(text: widget.edit?.name ?? '');
  late final _specialty =
      TextEditingController(text: widget.edit?.specialty ?? '');
  late final _phone = TextEditingController(text: widget.edit?.phone ?? '');
  late final _commission = TextEditingController(
      text: (widget.edit != null && widget.edit!.commissionRate > 0)
          ? _trim(widget.edit!.commissionRate)
          : '');
  late bool _active = widget.edit?.active ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _specialty.dispose();
    _phone.dispose();
    _commission.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      _snack('El nombre es obligatorio.');
      return;
    }
    final rate = double.tryParse(_commission.text.replaceAll(',', '.'));
    if (rate != null && (rate < 0 || rate > 100)) {
      _snack('La comisión debe estar entre 0 y 100.');
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(workshopRepositoryProvider);
      final args = (
        name: _name.text.trim(),
        specialty: _specialty.text.trim().isEmpty ? null : _specialty.text.trim(),
        phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
        commissionRate: rate,
        active: _active,
      );
      if (widget.edit != null) {
        await repo.updateMechanic(widget.edit!.id,
            name: args.name,
            specialty: args.specialty,
            phone: args.phone,
            commissionRate: args.commissionRate,
            active: args.active);
      } else {
        await repo.createMechanic(
            name: args.name,
            specialty: args.specialty,
            phone: args.phone,
            commissionRate: args.commissionRate,
            active: args.active);
      }
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
    return Scaffold(
      appBar: AppBar(
          title: Text(widget.edit != null ? 'Editar mecánico' : 'Nuevo mecánico')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Nombre *', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _specialty,
            decoration: const InputDecoration(
                labelText: 'Especialidad',
                hintText: 'Ej: Motor, eléctrico, suspensión…',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Teléfono', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _commission,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Comisión (%)',
                suffixText: '%',
                helperText: 'Sobre la mano de obra de sus OTs entregadas (0–100).',
                border: OutlineInputBorder()),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Activo'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: const Text('Guardar mecánico'),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
