import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/app_toast.dart';
import '../../core/module_colors.dart';
import '../../core/sheet_focus.dart';
import '../../core/upper_case.dart';
import 'catalogs_repository.dart';

/// Campo "Modelos compatibles" del producto: muestra los elegidos como chips
/// (con ✕ para quitar) y al tocarlo abre una hoja para marcar varios, con
/// búsqueda por modelo o por marca ("HONDA" encuentra CG 150, XR 190…).
/// Si lo buscado no existe, ofrece **crearlo** ahí mismo (con su marca de moto).
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
  String _q = '';

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
    setState(() => _q = v.trim());
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () => _load(v));
  }

  /// ¿Lo escrito ya es un modelo de la lista? ("CG 150" o "HONDA CG 150").
  bool get _exists {
    final q = _q.toUpperCase();
    return _items.any(
      (m) => m.name.toUpperCase() == q || _label(m).toUpperCase() == q,
    );
  }

  Future<void> _create() async {
    final created = await showDialog<CatalogItem>(
      context: context,
      builder: (_) => _NewMotoModelDialog(typed: _q),
    );
    if (created == null || !mounted) return;
    // Otras pantallas (Inventario → Modelos / Marcas) se refrescan solas.
    ref.invalidate(catalogListProvider(CatalogType.motoModels));
    ref.invalidate(catalogListProvider(CatalogType.motoBrands));
    _search.clear();
    setState(() {
      _q = '';
      _selected[created.id] = created;
      _items = [created, ..._items.where((m) => m.id != created.id)];
    });
    AppToast.success(context, '${_label(created)} creado y agregado.');
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
            if (_q.isNotEmpty && !_loading && !_exists)
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: ModuleColors.soft(color),
                  child: Icon(Icons.add, color: color),
                ),
                title: Text('Crear «${_q.toUpperCase()}»'),
                subtitle: const Text('No está en la lista: agrégalo ahora'),
                onTap: _create,
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        _q.isEmpty
                            ? 'Todavía no hay modelos. Escribe uno arriba para crearlo.'
                            : 'No hay modelos con ese nombre.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.black54),
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

/// Alta rápida de un modelo de moto desde el selector. Si lo escrito empieza
/// con una marca que ya existe ("HONDA CG 150"), la deja elegida y usa el resto
/// como nombre. Si la marca no existe, se puede escribir y se crea también.
/// Devuelve el modelo creado (o el existente si ya había uno igual).
class _NewMotoModelDialog extends ConsumerStatefulWidget {
  final String typed;
  const _NewMotoModelDialog({required this.typed});

  @override
  ConsumerState<_NewMotoModelDialog> createState() =>
      _NewMotoModelDialogState();
}

class _NewMotoModelDialogState extends ConsumerState<_NewMotoModelDialog> {
  late final _name = TextEditingController(text: widget.typed.toUpperCase());
  final _newBrand = TextEditingController();
  final _cc = TextEditingController();

  List<CatalogItem> _brands = [];
  int? _brandId;
  bool _otherBrand = false;
  bool _loading = true;
  bool _saving = false;

  /// Valor del desplegable para "Otra marca…".
  static const _other = -1;

  @override
  void initState() {
    super.initState();
    _loadBrands();
  }

  @override
  void dispose() {
    _name.dispose();
    _newBrand.dispose();
    _cc.dispose();
    super.dispose();
  }

  Future<void> _loadBrands() async {
    try {
      final all = await ref
          .read(catalogsRepositoryProvider)
          .list(CatalogType.motoBrands);
      if (!mounted) return;
      final brands = all.where((b) => b.active).toList();
      // "HONDA CG 150" → marca HONDA + modelo "CG 150".
      final typed = widget.typed.trim().toUpperCase();
      int? guess;
      var name = typed;
      for (final b in brands) {
        final bn = b.name.toUpperCase();
        if (typed.startsWith('$bn ') && typed.length > bn.length + 1) {
          guess = b.id;
          name = typed.substring(bn.length + 1).trim();
          break;
        }
      }
      setState(() {
        _brands = brands;
        _brandId = guess;
        _otherBrand = brands.isEmpty;
        _name.text = name;
        _loading = false;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _otherBrand = true;
      });
      AppToast.apiError(context, e);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final newBrand = _newBrand.text.trim();
    if (name.isEmpty) {
      AppToast.error(context, 'Escribe el nombre del modelo.');
      return;
    }
    if (!_otherBrand && _brandId == null) {
      AppToast.error(context, 'Elige la marca del vehículo.');
      return;
    }
    if (_otherBrand && newBrand.isEmpty) {
      AppToast.error(context, 'Escribe la marca del vehículo.');
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(catalogsRepositoryProvider);
      var brandId = _brandId;
      if (_otherBrand) {
        // El backend reutiliza la marca si ya existía con ese nombre.
        brandId = (await repo.create(
          CatalogType.motoBrands,
          name: newBrand,
        )).id;
      }
      final model = await repo.create(
        CatalogType.motoModels,
        name: name,
        extra: {
          'moto_brand_id': brandId,
          'engine_cc': _cc.text.trim().isEmpty ? null : _cc.text.trim(),
        },
      );
      if (mounted) Navigator.pop(context, model);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.apiError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const dec = OutlineInputBorder();
    return AlertDialog(
      title: const Text('Nuevo modelo'),
      content: _loading
          ? const SizedBox(
              height: 80,
              child: Center(child: CircularProgressIndicator()),
            )
          : SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_brands.isNotEmpty)
                    DropdownButtonFormField<int>(
                      initialValue: _otherBrand ? _other : _brandId,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Marca de vehículo *',
                        border: dec,
                      ),
                      items: [
                        for (final b in _brands)
                          DropdownMenuItem(value: b.id, child: Text(b.name)),
                        const DropdownMenuItem(
                          value: _other,
                          child: Text('➕ Otra marca…'),
                        ),
                      ],
                      onChanged: (v) => setState(() {
                        _otherBrand = v == _other;
                        _brandId = v == _other ? null : v;
                      }),
                    ),
                  if (_otherBrand) ...[
                    if (_brands.isNotEmpty) const SizedBox(height: 12),
                    TextField(
                      controller: _newBrand,
                      textCapitalization: TextCapitalization.characters,
                      inputFormatters: upperCaseFormatters,
                      decoration: const InputDecoration(
                        labelText: 'Marca nueva *',
                        hintText: 'Ej. ZONGSHEN, TOYOTA',
                        border: dec,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: _name,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: upperCaseFormatters,
                    decoration: const InputDecoration(
                      labelText: 'Modelo *',
                      hintText: 'Ej. CG 150, COROLLA',
                      border: dec,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _cc,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: upperCaseFormatters,
                    decoration: const InputDecoration(
                      labelText: 'Cilindrada (opcional)',
                      hintText: 'Ej. 150',
                      border: dec,
                    ),
                  ),
                ],
              ),
            ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        // El tema da a FilledButton ancho mínimo infinito: dentro de las
        // acciones (una fila) hay que acotarlo o la ventana sale en blanco.
        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size(0, 40),
            padding: const EdgeInsets.symmetric(horizontal: 16),
          ),
          onPressed: _saving || _loading ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Text('Crear y agregar'),
        ),
      ],
    );
  }
}
