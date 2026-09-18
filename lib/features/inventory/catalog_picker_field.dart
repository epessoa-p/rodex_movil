import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/app_toast.dart';
import '../../core/models.dart';
import '../../core/sheet_focus.dart';
import 'catalogs_repository.dart';

/// Campo "Categoría / Marca" del formulario de producto: al tocarlo abre una
/// hoja con buscador; si lo escrito no existe, ofrece **crear** «X» al vuelo
/// (el backend reutiliza uno existente con el mismo nombre). Devuelve la
/// opción elegida por [onChanged] (null = sin valor).
class CatalogPickerField extends ConsumerWidget {
  final String label;
  final CatalogType type;
  final List<IdName> options;
  final int? value;
  final ValueChanged<IdName?> onChanged;

  /// Se llama tras crear una opción nueva (para refrescar el catálogo padre).
  final ValueChanged<IdName>? onCreated;

  const CatalogPickerField({
    super.key,
    required this.label,
    required this.type,
    required this.options,
    required this.value,
    required this.onChanged,
    this.onCreated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    IdName? current;
    for (final o in options) {
      if (o.id == value) current = o;
    }
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => _open(context, ref),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          // Vacío: la etiqueta baja y hace de placeholder (sin texto encima).
          hintText: 'Buscar o crear…',
          border: const OutlineInputBorder(),
          suffixIcon: value == null
              ? const Icon(Icons.search)
              : IconButton(
                  tooltip: 'Quitar',
                  icon: const Icon(Icons.clear),
                  onPressed: () => onChanged(null),
                ),
        ),
        isEmpty: current == null,
        child: Text(
          current?.name ?? '',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref) async {
    final picked = await showModalBottomSheet<IdName>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _PickerSheet(
        label: label,
        type: type,
        options: options,
        repo: ref.read(catalogsRepositoryProvider),
        onCreated: onCreated,
      ),
    );
    if (picked != null) onChanged(picked);
  }
}

class _PickerSheet extends StatefulWidget {
  final String label;
  final CatalogType type;
  final List<IdName> options;
  final CatalogsRepository repo;
  final ValueChanged<IdName>? onCreated;
  const _PickerSheet({
    required this.label,
    required this.type,
    required this.options,
    required this.repo,
    this.onCreated,
  });

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  final _search = TextEditingController();
  // Foco diferido (sin autofocus en hojas: ver SheetFocus).
  late final SheetFocus _focus = SheetFocus(this);
  String _q = '';
  bool _creating = false;

  @override
  void dispose() {
    _focus.dispose();
    _search.dispose();
    super.dispose();
  }

  List<IdName> get _filtered => _q.isEmpty
      ? widget.options
      : widget.options
            .where((o) => o.name.toLowerCase().contains(_q.toLowerCase()))
            .toList();

  bool get _exactExists =>
      widget.options.any((o) => o.name.toLowerCase() == _q.toLowerCase());

  Future<void> _create() async {
    final name = _q.trim().toUpperCase();
    if (name.isEmpty) return;
    setState(() => _creating = true);
    try {
      final item = await widget.repo.create(widget.type, name: name);
      final opt = IdName(id: item.id, name: item.name);
      widget.onCreated?.call(opt);
      if (mounted) Navigator.pop(context, opt);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        AppToast.apiError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _filtered;
    final showCreate = _q.trim().isNotEmpty && !_exactExists;
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.7,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: TextField(
                controller: _search,
                focusNode: _focus.node,
                textCapitalization: TextCapitalization.characters,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search),
                  hintText:
                      'Buscar o escribir ${widget.label.toLowerCase()} nueva…',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: (v) => setState(() => _q = v.trim()),
                onSubmitted: (_) {
                  if (list.length == 1) {
                    Navigator.pop(context, list.first);
                  } else if (showCreate) {
                    _create();
                  }
                },
              ),
            ),
            if (showCreate)
              ListTile(
                leading: _creating
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.add_circle, color: Colors.green),
                title: Text('Crear «${_q.toUpperCase()}»'),
                subtitle: Text('Nueva ${widget.label.toLowerCase()}'),
                onTap: _creating ? null : _create,
              ),
            if (showCreate) const Divider(height: 1),
            Expanded(
              child: list.isEmpty
                  ? Center(
                      child: Text(
                        widget.options.isEmpty
                            ? 'Aún no hay ${widget.label.toLowerCase()}s: escribe una para crearla.'
                            : 'Sin coincidencias.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) => ListTile(
                        title: Text(list[i].name),
                        onTap: () => Navigator.pop(context, list[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
