import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/module_colors.dart';
import '../../core/sheet_focus.dart';
import 'catalogs_repository.dart';

/// Campo "Modelos compatibles" del producto: muestra los elegidos como chips
/// (con ✕ para quitar) y al tocarlo abre una hoja para marcar varios, con
/// búsqueda por modelo o por marca ("HONDA" encuentra CG 150, XR 190…).
class MotoModelsField extends StatelessWidget {
  final List<CatalogItem> value;
  final ValueChanged<List<CatalogItem>> onChanged;

  const MotoModelsField({
    super.key,
    required this.value,
    required this.onChanged,
  });

  Future<void> _open(BuildContext context) async {
    final picked = await showModalBottomSheet<List<CatalogItem>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _MotoModelsSheet(initial: value),
    );
    if (picked != null) onChanged(picked);
  }

  @override
  Widget build(BuildContext context) {
    final color = ModuleColors.models;
    return InkWell(
      borderRadius: BorderRadius.circular(4),
      onTap: () => _open(context),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: 'Modelos compatibles',
          // Ayuda abajo (no hint): el hint largo se partía en dos líneas y
          // hacía el campo más alto que los demás.
          helperText: 'Puedes elegir varios modelos.',
          border: const OutlineInputBorder(),
          suffixIcon: Icon(Icons.two_wheeler, color: color),
        ),
        isEmpty: value.isEmpty,
        child: value.isEmpty
            ? const SizedBox.shrink()
            : Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final m in value)
                    InputChip(
                      label: Text(_label(m), overflow: TextOverflow.ellipsis),
                      visualDensity: VisualDensity.compact,
                      backgroundColor: ModuleColors.soft(color),
                      side: BorderSide.none,
                      onDeleted: () =>
                          onChanged(value.where((e) => e.id != m.id).toList()),
                      deleteButtonTooltipMessage: 'Quitar',
                    ),
                ],
              ),
      ),
    );
  }
}

/// "HONDA CG 150" si el modelo trae la marca; si no, solo el nombre.
String _label(CatalogItem m) =>
    (m.brand != null && m.brand!.isNotEmpty) ? '${m.brand} ${m.name}' : m.name;

class _MotoModelsSheet extends ConsumerStatefulWidget {
  final List<CatalogItem> initial;
  const _MotoModelsSheet({required this.initial});

  @override
  ConsumerState<_MotoModelsSheet> createState() => _MotoModelsSheetState();
}

class _MotoModelsSheetState extends ConsumerState<_MotoModelsSheet> {
  final _search = TextEditingController();
  late final _focus = SheetFocus(this);
  late final Map<int, CatalogItem> _selected = {
    for (final m in widget.initial) m.id: m,
  };
  List<CatalogItem> _items = [];
  bool _loading = true;
  String? _error;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _load(String q) async {
    setState(() => _loading = true);
    try {
      final all = await ref
          .read(catalogsRepositoryProvider)
          .list(CatalogType.motoModels, q: q.trim());
      if (!mounted) return;
      setState(() {
        // Solo activos: un modelo dado de baja no se ofrece para productos nuevos.
        _items = all.where((m) => m.active).toList();
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message;
          _loading = false;
        });
      }
    }
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(v));
  }

  void _toggle(CatalogItem m) => setState(() {
    if (_selected.containsKey(m.id)) {
      _selected.remove(m.id);
    } else {
      _selected[m.id] = m;
    }
  });

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.82;
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    final color = ModuleColors.models;

    // Elegidos primero: así se ve de un vistazo qué ya está marcado.
    final list = [
      ..._items.where((m) => _selected.containsKey(m.id)),
      ..._items.where((m) => !_selected.containsKey(m.id)),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: height,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.two_wheeler, color: color),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Modelos compatibles',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_selected.isNotEmpty)
                    TextButton(
                      onPressed: () => setState(_selected.clear),
                      child: const Text('Quitar todos'),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: _search,
                focusNode: _focus.node,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                  hintText: 'Modelo o marca (ej. HONDA)',
                  prefixIcon: Icon(Icons.search),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onChanged: _onSearch,
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No hay modelos con ese nombre.\n'
                        'Puedes crearlos en Inventario → Modelos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.black54),
                      ),
                    )
                  : ListView.builder(
                      itemCount: list.length,
                      itemBuilder: (_, i) {
                        final m = list[i];
                        final on = _selected.containsKey(m.id);
                        final sub = [
                          if (m.brand != null && m.brand!.isNotEmpty) m.brand!,
                          if (m.engineCc != null && m.engineCc!.isNotEmpty)
                            m.engineCc!,
                          if (m.year != null) '${m.year}',
                        ].join(' · ');
                        return CheckboxListTile(
                          value: on,
                          onChanged: (_) => _toggle(m),
                          activeColor: color,
                          controlAffinity: ListTileControlAffinity.leading,
                          title: Text(
                            m.name,
                            style: TextStyle(
                              fontWeight: on
                                  ? FontWeight.w700
                                  : FontWeight.normal,
                            ),
                          ),
                          subtitle: sub.isEmpty ? null : Text(sub),
                          dense: true,
                        );
                      },
                    ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  icon: const Icon(Icons.check),
                  label: Text(
                    _selected.isEmpty
                        ? 'Listo'
                        : 'Listo · ${_selected.length} '
                              'modelo${_selected.length == 1 ? '' : 's'}',
                  ),
                  onPressed: () =>
                      Navigator.pop(context, _selected.values.toList()),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
