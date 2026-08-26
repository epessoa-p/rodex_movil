import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../pos/pos_repository.dart';

class ClientsScreen extends ConsumerStatefulWidget {
  final void Function(Client)? onPick;
  const ClientsScreen({super.key, this.onPick});

  @override
  ConsumerState<ClientsScreen> createState() => _ClientsScreenState();
}

class _ClientsScreenState extends ConsumerState<ClientsScreen> {
  final _search = TextEditingController();
  List<Client> _items = [];
  bool _loading = true;
  String? _error;

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
    setState(() => _loading = true);
    try {
      final items = await ref.read(posRepositoryProvider).clients(q: q);
      if (mounted) {
        setState(() {
          _items = items;
          _loading = false;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _createDialog() async {
    final name = TextEditingController();
    final phone = TextEditingController();
    final idNum = TextEditingController();
    final created = await showDialog<Client>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Nuevo cliente'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
                controller: name,
                decoration: const InputDecoration(
                    labelText: 'Nombre completo *')),
            const SizedBox(height: 8),
            TextField(
                controller: phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Teléfono')),
            const SizedBox(height: 8),
            TextField(
                controller: idNum,
                decoration: const InputDecoration(labelText: 'Documento')),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancelar')),
          FilledButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) return;
              try {
                final c = await ref.read(posRepositoryProvider).createClient(
                      fullName: name.text.trim(),
                      phone: phone.text.trim(),
                      idNumber: idNum.text.trim(),
                    );
                if (ctx.mounted) Navigator.pop(ctx, c);
              } on ApiException catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx)
                      .showSnackBar(SnackBar(content: Text(e.message)));
                }
              }
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (created != null) {
      if (widget.onPick != null) {
        widget.onPick!(created);
      } else {
        _load('');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final picking = widget.onPick != null;
    return Scaffold(
      appBar: AppBar(title: Text(picking ? 'Elegir cliente' : 'Clientes')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createDialog,
        icon: const Icon(Icons.person_add_alt),
        label: const Text('Nuevo'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _search,
              decoration: const InputDecoration(
                hintText: 'Buscar por nombre, teléfono o documento',
                prefixIcon: Icon(Icons.search),
              ),
              textInputAction: TextInputAction.search,
              onSubmitted: _load,
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Center(child: Text(_error!))
                    : _items.isEmpty
                        ? const Center(child: Text('Sin clientes.'))
                        : ListView.separated(
                            itemCount: _items.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final c = _items[i];
                              return ListTile(
                                leading: CircleAvatar(
                                    child: Text(c.fullName.isNotEmpty
                                        ? c.fullName[0].toUpperCase()
                                        : '?')),
                                title: Text(c.fullName),
                                subtitle: Text(
                                    [c.phone, c.idNumber]
                                        .where((e) =>
                                            e != null && e.isNotEmpty)
                                        .join('  ·  '),
                                    maxLines: 1),
                                onTap: picking
                                    ? () => widget.onPick!(c)
                                    : null,
                              );
                            },
                          ),
          ),
        ],
      ),
    );
  }
}
