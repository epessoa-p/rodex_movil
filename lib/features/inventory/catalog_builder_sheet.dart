import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/app_toast.dart';
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

  /// PDF con la foto de cada producto (solo afecta al PDF).
  final bool photos;
  const CatalogSelection({
    this.categories = const {},
    this.brands = const {},
    this.models = const {},
    this.onlyInStock = false,
    this.photos = false,
  });

  /// ¿Eligió categoría, marca o modelo? (obligatorio para el PDF con fotos).
  bool get narrows =>
      categories.isNotEmpty || brands.isNotEmpty || models.isNotEmpty;

  /// Motivo por el que no se puede bajar el PDF con fotos (null = se puede).
  String? photoBlock(int? count, int max) {
    if (!photos) return null;
    if (!narrows) {
      return 'Para el PDF con fotos elige al menos una categoría, marca o '
          'modelo: con todo el catálogo sería muy pesado y lento.';
    }
    if (count != null && count > max) {
      return 'Son $count productos: con fotos el máximo es $max. Elige menos '
          'o desactiva las fotos.';
    }
    return null;
  }

  bool get isEmpty =>
      categories.isEmpty && brands.isEmpty && models.isEmpty && !onlyInStock;

  CatalogSelection copyWith({
    Set<int>? categories,
    Set<int>? brands,
    Set<int>? models,
    bool? onlyInStock,
    bool? photos,
  }) => CatalogSelection(
    categories: categories ?? this.categories,
    brands: brands ?? this.brands,
    models: models ?? this.models,
    onlyInStock: onlyInStock ?? this.onlyInStock,
    photos: photos ?? this.photos,
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

  /// La URL del catálogo con esta selección. Con [pdf] también lleva las
  /// fotos (la página web siempre las muestra).
  String applyTo(String url, {bool pdf = false}) {
    final q = {...query, if (pdf && photos) 'fotos': '1'};
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

  /// Máximo de productos en el PDF con fotos.
  final int photoMax;
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
    this.photoMax = 300,
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
    final block = _counting
        ? _sel.photoBlock(null, widget.photoMax)
        : _sel.photoBlock(_count, widget.photoMax);
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
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: SwitchListTile(
                        key: const Key('with_photos'),
                        secondary: const Icon(Icons.photo_library_outlined),
                        title: const Text('Incluir fotos en el PDF'),
                        subtitle: Text(
                          'Elige al menos una categoría, marca o modelo '
                          '(máx. ${widget.photoMax} productos).',
                          style: const TextStyle(fontSize: 12),
                        ),
                        value: _sel.photos,
                        onChanged: (v) => _set(_sel.copyWith(photos: v)),
                      ),
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
                        color:
                            (block != null
                                    ? Colors.red
                                    : tooMany
                                    ? Colors.orange
                                    : Colors.blueGrey)
                                .withValues(alpha: .10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            block != null
                                ? Icons.warning_amber_rounded
                                : tooMany
                                ? Icons.hourglass_bottom
                                : Icons.inventory_2_outlined,
                            size: 18,
                            color: block != null
                                ? Colors.red.shade700
                                : tooMany
                                ? Colors.orange.shade800
                                : Colors.black54,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              block ??
                                  (tooMany
                                      ? '$countText: el PDF puede tardar. Conviene filtrar.'
                                      : countText),
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
                          : () {
                              if (block != null) {
                                AppToast.error(
                                  context,
                                  block,
                                  title: 'Elige un filtro',
                                );
                                return;
                              }
                              _run(widget.onPdf);
                            },
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
