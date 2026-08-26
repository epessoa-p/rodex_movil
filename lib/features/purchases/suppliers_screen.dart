import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import 'purchases_repository.dart';

/// Directorio de proveedores: listar/buscar y alta rápida.
class SuppliersScreen extends ConsumerStatefulWidget {
  const SuppliersScreen({super.key});

  @override
  ConsumerState<SuppliersScreen> createState() => _SuppliersScreenState();
}

class _SuppliersScreenState extends ConsumerState<SuppliersScreen> {
  final _search = TextEditingController();
  List<Supplier> _items = [];
  bool _loading = true;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load(String q) async {
    setState(() { _loading = true; _error = null; });
    try {
      final items = await ref.read(purchasesRepositoryProvider).suppliers(q: q);
      if (mounted) setState(() { _items = items; _loading = false; });
    } on ApiException catch (e) {
      if (mounted) setState(() { _error = e.message; _loading = false; });
    }
  }

  Future<void> _addDialog() async {
    final name = TextEditingController();
    final nit = TextEditingController();
    final contact = TextEditingController();
    final phone = TextEditingController();
    final email = TextEditingController();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo proveedor'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre *'),
              ),
              TextField(
                controller: nit,
                decoration: const InputDecoration(labelText: 'NIT / documento'),
              ),
              TextField(
                controller: contact,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Contacto'),
              ),
              TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono'),
              ),
              TextField(
                controller: email,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar')),
        ],
      ),
    );

    if (ok != true) return;
    if (name.text.trim().isEmpty) {
      _snack('El nombre es obligatorio.');
      return;
    }
    try {
      final s = await ref.read(purchasesRepositoryProvider).createSupplier(
            name: name.text.trim(),
            nit: nit.text.trim().isEmpty ? null : nit.text.trim(),
            contactName: contact.text.trim().isEmpty ? null : contact.text.trim(),
            phone: phone.text.trim().isEmpty ? null : phone.text.trim(),
            email: email.text.trim().isEmpty ? null : email.text.trim(),
          );
      if (mounted) {
        setState(() => _items = [s, ..._items]);
        _snack('Proveedor "${s.name}" creado.');
      }
    } on ApiException catch (e) {
      if (mounted) _snack(e.message);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Proveedores')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addDialog,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              textInputAction: TextInputAction.search,
              onSubmitted: _load,
              decoration: InputDecoration(
                hintText: 'Buscar por nombre, NIT o teléfono',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.clear),
                  onPressed: () { _search.clear(); _load(''); },
                ),
                isDense: true,
                border:
                    OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text('$_error', textAlign: TextAlign.center),
                        ),
                      )
                    : _items.isEmpty
                        ? const Center(child: Text('Sin proveedores.'))
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final s = _items[i];
                              final sub = [
                                if (s.nit != null && s.nit!.isNotEmpty)
                                  'NIT ${s.nit}',
                                if (s.contactName != null &&
                                    s.contactName!.isNotEmpty)
                                  s.contactName!,
                                if (s.phone != null && s.phone!.isNotEmpty)
                                  s.phone!,
                              ].join('  ·  ');
                              return ListTile(
                                leading: CircleAvatar(
                                  child: Text(s.name.isNotEmpty
                                      ? s.name[0].toUpperCase()
                                      : '?'),
                                ),
                                title: Text(s.name),
                                subtitle: sub.isEmpty ? null : Text(sub),
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
