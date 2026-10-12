import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/format.dart';

/// Una opción del armador (categoría, marca o modelo de vehículo).
class CatalogOption {
  final int id;
  final String name;

  /// Marca del vehículo para los modelos ("HONDA").
  final String? brand;
  const CatalogOption({required this.id, required this.name, this.brand});

  String get label => brand == null || brand!.isEmpty ? name : '$name · $brand';

  factory CatalogOption.fromJson(Map<String, dynamic> j) => CatalogOption(
    id: (j['id'] as num).toInt(),
    name: (j['name'] ?? '') as String,
    brand: j['brand'] as String?,
  );
}

/// Categorías, marcas y modelos que tienen productos activos.
class CatalogFilterOptions {
  final List<CatalogOption> categories;
  final List<CatalogOption> brands;
  final List<CatalogOption> models;
  const CatalogFilterOptions({
    this.categories = const [],
    this.brands = const [],
    this.models = const [],
  });

  bool get isEmpty => categories.isEmpty && brands.isEmpty && models.isEmpty;

  factory CatalogFilterOptions.fromJson(Map<String, dynamic>? j) {
    List<CatalogOption> list(String k) => ((j?[k] as List?) ?? [])
        .map((e) => CatalogOption.fromJson((e as Map).cast<String, dynamic>()))
        .toList();
    return CatalogFilterOptions(
      categories: list('categories'),
      brands: list('brands'),
      models: list('models'),
    );
  }
}

/// Parte del catálogo elegida. Viaja en la URL pública como
/// ?cat=1,4&mar=2&mod=7,9&stock=1 (igual que la web).
class CatalogSelection {
  final Set<int> categories;
  final Set<int> brands;
  final Set<int> models;
  final bool onlyInStock;
  const CatalogSelection({
    this.categories = const {},
    this.brands = const {},
    this.models = const {},
    this.onlyInStock = false,
  });

  bool get isEmpty =>
      categories.isEmpty && brands.isEmpty && models.isEmpty && !onlyInStock;

  CatalogSelection copyWith({
    Set<int>? categories,
    Set<int>? brands,
    Set<int>? models,
    bool? onlyInStock,
  }) => CatalogSelection(
    categories: categories ?? this.categories,
    brands: brands ?? this.brands,
    models: models ?? this.models,
    onlyInStock: onlyInStock ?? this.onlyInStock,
  );

  Map<String, String> get query {
    String join(Set<int> s) => (s.toList()..sort()).join(',');
    return {
      if (categories.isNotEmpty) 'cat': join(categories),
      if (brands.isNotEmpty) 'mar': join(brands),
      if (models.isNotEmpty) 'mod': join(models),
      if (onlyInStock) 'stock': '1',
    };
  }

  /// La URL del catálogo (página o PDF) con esta selección.
  String applyTo(String url) {
    final q = query;
    if (q.isEmpty) return url;
    // Las comas quedan legibles (el servidor acepta "1,4").
    final qs = q.entries.map((e) => '${e.key}=${e.value}').join('&');
    return '${url.split('?').first}?$qs';
  }
}

/// Hoja "Armar catálogo": elegir categorías, marcas, modelos y "solo
/// disponibles", ver cuántos productos quedan y descargar el PDF o compartir
/// el enlace de esa parte del catálogo.
class CatalogBuilderSheet extends StatefulWidget {
  final String branchName;
  final CatalogFilterOptions options;

  /// Avisar si el PDF tendría más productos que esto (tarda en generarse).
  final int warnAt;
  final Future<int> Function(CatalogSelection) count;
  final Future<void> Function(CatalogSelection) onPdf;
  final Future<void> Function(CatalogSelection) onShare;

  const CatalogBuilderSheet({
    super.key,
    required this.branchName,
    required this.options,
    required this.count,
    required this.onPdf,
    required this.onShare,
    this.warnAt = 500,
  });

  @override
  State<CatalogBuilderSheet> createState() => _CatalogBuilderSheetState();
}

class _CatalogBuilderSheetState extends State<CatalogBuilderSheet> {
  CatalogSelection _sel = const CatalogSelection();
  int? _count;
  bool _counting = true;
  bool _busy = false;
  Timer? _debounce;
  int _seq = 0;

  @override
  void initState() {
    super.initState();
    // Conteo inicial fuera del build (no se toca el estado del padre).
    WidgetsBinding.instance.addPostFrameCallback((_) => _recount());
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _set(CatalogSelection s) {
    setState(() {
      _sel = s;
      _counting = true;
    });
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _recount);
  }

  Future<void> _recount() async {
    final mine = ++_seq;
    try {
      final n = await widget.count(_sel);
      if (!mounted || mine != _seq) return;
      setState(() {
        _count = n;
        _counting = false;
      });
    } catch (_) {
      if (!mounted || mine != _seq) return;
      setState(() {
        _count = null;
        _counting = false;
      });
    }
  }

  Future<void> _run(Future<void> Function(CatalogSelection) action) async {
    setState(() => _busy = true);
    try {
      await action(_sel);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Set<int> _toggle(Set<int> s, int id) =>
      s.contains(id) ? ({...s}..remove(id)) : {...s, id};

  @override
  Widget build(BuildContext context) {
    final o = widget.options;
    final countText = _counting
        ? 'Contando…'
        : _count == null
        ? 'No se pudo contar'
        : _count == 1
        ? '1 producto'
        : '${qty(_count!)} productos';
    final tooMany = !_counting && (_count ?? 0) > widget.warnAt;
    final none = !_counting && _count == 0;
    final full = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size.fromHeight(46)),
    );

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * .88,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 8, 0),
                child: Row(
                  children: [
                    const Icon(Icons.filter_alt_outlined),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Armar catálogo · ${widget.branchName}',
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cerrar',
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(
                  'Elige qué incluir. Sin elegir nada va todo el catálogo. '
                  'Puedes combinar: por ejemplo, Aceites compatibles con CG.',
                  style: TextStyle(fontSize: 12, color: Colors.black54),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    SwitchListTile(
                      key: const Key('only_stock'),
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Solo disponibles en esta sucursal'),
                      value: _sel.onlyInStock,
                      onChanged: (v) => _set(_sel.copyWith(onlyInStock: v)),
                    ),
                    if (o.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text(
                          'Tus productos aún no tienen categorías, marcas ni '
                          'modelos: solo puedes filtrar por disponibles.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ),
                    if (o.categories.isNotEmpty)
                      _OptionGroup(
                        key: const Key('group_categories'),
                        title: 'Categorías',
                        options: o.categories,
                        selected: _sel.categories,
                        onToggle: (id) => _set(
                          _sel.copyWith(
                            categories: _toggle(_sel.categories, id),
                          ),
                        ),
                      ),
                    if (o.brands.isNotEmpty)
                      _OptionGroup(
                        key: const Key('group_brands'),
                        title: 'Marcas',
                        options: o.brands,
                        selected: _sel.brands,
                        onToggle: (id) => _set(
                          _sel.copyWith(brands: _toggle(_sel.brands, id)),
                        ),
                      ),
                    if (o.models.isNotEmpty)
                      _OptionGroup(
                        key: const Key('group_models'),
                        title: 'Modelos de vehículo compatibles',
                        options: o.models,
                        selected: _sel.models,
                        onToggle: (id) => _set(
                          _sel.copyWith(models: _toggle(_sel.models, id)),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: (tooMany ? Colors.orange : Colors.blueGrey)
                            .withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            tooMany
                                ? Icons.hourglass_bottom
                                : Icons.inventory_2_outlined,
                            size: 18,
                            color: tooMany
                                ? Colors.orange.shade800
                                : Colors.black54,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tooMany
                                  ? '$countText: el PDF puede tardar. Conviene filtrar.'
                                  : countText,
                              key: const Key('builder_count'),
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    FilledButton.icon(
                      key: const Key('builder_pdf'),
                      style: full,
                      icon: _busy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.picture_as_pdf_outlined),
                      label: const Text('Descargar PDF'),
                      onPressed: _busy || none
                          ? null
                          : () => _run(widget.onPdf),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const Key('builder_share'),
                      style: full,
                      icon: const Icon(Icons.share),
                      label: const Text('Compartir enlace de esta selección'),
                      onPressed: none ? null : () => _run(widget.onShare),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Grupo de chips con buscador (cuando hay muchas opciones).
class _OptionGroup extends StatefulWidget {
  final String title;
  final List<CatalogOption> options;
  final Set<int> selected;
  final ValueChanged<int> onToggle;
  const _OptionGroup({
    super.key,
    required this.title,
    required this.options,
    required this.selected,
    required this.onToggle,
  });

  @override
  State<_OptionGroup> createState() => _OptionGroupState();
}

class _OptionGroupState extends State<_OptionGroup> {
  final _search = TextEditingController();
  static const _searchFrom = 8;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _search.text.trim().toLowerCase();
    // Los elegidos siempre se ven (aunque no coincidan con la búsqueda).
    final shown = widget.options
        .where(
          (o) =>
              q.isEmpty ||
              widget.selected.contains(o.id) ||
              o.label.toLowerCase().contains(q),
        )
        .toList();
    final n = widget.selected.length;

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            n == 0 ? widget.title : '${widget.title} ($n)',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          if (widget.options.length > _searchFrom)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: 'Buscar ${widget.title.toLowerCase()}…',
                  prefixIcon: const Icon(Icons.search, size: 20),
                  border: const OutlineInputBorder(),
                ),
              ),
            ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final o in shown)
                FilterChip(
                  label: Text(o.label, overflow: TextOverflow.ellipsis),
                  selected: widget.selected.contains(o.id),
                  visualDensity: VisualDensity.compact,
                  onSelected: (_) => widget.onToggle(o.id),
                ),
              if (shown.isEmpty)
                const Text(
                  'Sin coincidencias.',
                  style: TextStyle(color: Colors.black54),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
