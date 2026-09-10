import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import 'branches_repository.dart';

/// Sucursales (Ajustes → Sucursales). Alcance acotado: se listan y se editan
/// solo nombre, dirección y teléfono. El alta/baja queda en el panel web.
class BranchesScreen extends ConsumerStatefulWidget {
  const BranchesScreen({super.key});

  @override
  ConsumerState<BranchesScreen> createState() => _BranchesScreenState();
}

class _BranchesScreenState extends ConsumerState<BranchesScreen> {
  List<BranchInfo> _items = [];
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
      final items = await ref.read(branchesRepositoryProvider).list();
      if (mounted) {
        setState(() {
          _items = items;
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

  Future<void> _edit(BranchInfo b) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _BranchForm(branch: b),
    );
    if (saved == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final canEdit =
        ref.watch(authControllerProvider).me?.can('branches.edit') ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Sucursales')),
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
                          Icon(Icons.store_mall_directory_outlined,
                              size: 56, color: Colors.black26),
                          SizedBox(height: 12),
                          Center(child: Text('Sin sucursales registradas.')),
                        ])
                      : ListView.separated(
                          itemCount: _items.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, i) {
                            final b = _items[i];
                            final detail = [
                              if (b.address?.isNotEmpty == true) b.address!,
                              if (b.phone?.isNotEmpty == true) b.phone!,
                            ].join('  ·  ');
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor:
                                    (b.active ? Colors.indigo : Colors.grey)
                                        .withValues(alpha: .12),
                                child: Icon(Icons.storefront_outlined,
                                    color:
                                        b.active ? Colors.indigo : Colors.grey),
                              ),
                              title: Text(b.name),
                              subtitle: Text(
                                  detail.isEmpty ? 'Sin datos de contacto' : detail),
                              trailing: b.active
                                  ? (canEdit ? const Icon(Icons.chevron_right) : null)
                                  : const Text('Inactiva',
                                      style: TextStyle(color: Colors.grey)),
                              onTap: canEdit ? () => _edit(b) : null,
                            );
                          },
                        ),
                ),
    );
  }
}

class _BranchForm extends ConsumerStatefulWidget {
  final BranchInfo branch;
  const _BranchForm({required this.branch});

  @override
  ConsumerState<_BranchForm> createState() => _BranchFormState();
}

class _BranchFormState extends ConsumerState<_BranchForm> {
  late final TextEditingController _name;
  late final TextEditingController _address;
  late final TextEditingController _phone;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.branch.name);
    _address = TextEditingController(text: widget.branch.address ?? '');
    _phone = TextEditingController(text: widget.branch.phone ?? '');
  }

  @override
  void dispose() {
    for (final c in [_name, _address, _phone]) {
      c.dispose();
    }
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
      await ref.read(branchesRepositoryProvider).update(
            widget.branch.id,
            name: _name.text.trim(),
            address: _address.text.trim(),
            phone: _phone.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
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
          const Text('Editar sucursal',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
                labelText: 'Nombre', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _address,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
                labelText: 'Dirección', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
                labelText: 'Teléfono', border: OutlineInputBorder()),
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
            label: const Text('Guardar'),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }
}
