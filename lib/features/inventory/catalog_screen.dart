import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/app_toast.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/upper_case.dart';
import '../../core/module_colors.dart';
import 'catalogs_repository.dart';

/// Tab genérico de catálogo (categorías, marcas, modelos, orígenes): listado
/// con buscador + alta/edición. Carga su lista solo cuando se construye
/// (el hub lo crea al entrar al tab por primera vez).
class CatalogScreen extends ConsumerStatefulWidget {
  final CatalogType type;
  final bool embedded;
  const CatalogScreen({super.key, required this.type, this.embedded = false});

  @override
  ConsumerState<CatalogScreen> createState() => _CatalogScreenState();
}

class _CatalogScreenState extends ConsumerState<CatalogScreen> {
  String _q = '';

  CatalogType get type => widget.type;

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).me;
    final canCreate = me?.can('${type.module}.create') ?? false;
    final canEdit = me?.can('${type.module}.edit') ?? false;
    final async = ref.watch(catalogListProvider(type));

    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: Text(type.title)),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              heroTag: 'fab-catalog-${type.path}',
              backgroundColor: ModuleColors.soft(type.color),
              foregroundColor: ModuleColors.onSoft(type.color),
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: Text(
                'Nuev${_fem ? 'a' : 'o'} ${type.singular.toLowerCase()}',
              ),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'Buscar en ${type.title.toLowerCase()}…',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(catalogListProvider(type)),
              child: async.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  children: [
                    const SizedBox(height: 80),
                    Center(child: Text('$e', textAlign: TextAlign.center)),
                  ],
                ),
                data: (all) {
                  final list = _q.isEmpty
                      ? all
                      : all
                            .where(
                              (c) =>
                                  c.name.toLowerCase().contains(_q) ||
                                  (c.brand ?? '').toLowerCase().contains(_q),
                            )
                            .toList();
                  if (list.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Text(
                            all.isEmpty
                                ? 'Aún no hay ${type.title.toLowerCase()}.'
                                : 'Sin resultados para «$_q».',
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 6),
                    itemBuilder: (_, i) {
                      final c = list[i];
                      final color = c.active ? type.color : Colors.grey;
                      return Card(
                        child: ListTile(
                          dense: true,
                          leading: CircleAvatar(
                            backgroundColor: color.withValues(alpha: .15),
                            child: Icon(_icon, color: color, size: 20),
                          ),
                          title: Text(
                            c.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: c.active ? null : Colors.grey,
                            ),
                          ),
                          subtitle: c.subtitle.isEmpty
                              ? null
                              : Text(c.subtitle),
                          trailing:
                              type == CatalogType.motoModels &&
                                  (c.suggestedPrice ?? 0) > 0
                              ? Text(
                                  money(c.suggestedPrice!),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                  ),
                                )
                              : (canEdit
                                    ? const Icon(Icons.chevron_right)
                                    : null),
                          onTap: canEdit ? () => _openForm(edit: c) : null,
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  bool get _fem =>
      type == CatalogType.categories ||
      type == CatalogType.brands ||
      type == CatalogType.motoBrands;

  IconData get _icon => switch (type) {
    CatalogType.categories => Icons.category_outlined,
    CatalogType.brands => Icons.sell_outlined,
    CatalogType.motoModels => Icons.two_wheeler_outlined,
    CatalogType.motoBrands => Icons.label_outline,
    CatalogType.origins => Icons.public_outlined,
  };

  Future<void> _openForm({CatalogItem? edit}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => CatalogFormScreen(type: type, edit: edit),
      ),
    );
    if (saved == true) ref.invalidate(catalogListProvider(type));
  }
}

/// Alta/edición de un registro de catálogo. Los campos extra dependen del tipo
/// (modelos: marca de moto, cilindrada, año, precio sugerido).
class CatalogFormScreen extends ConsumerStatefulWidget {
  final CatalogType type;
  final CatalogItem? edit;
  const CatalogFormScreen({super.key, required this.type, this.edit});

  @override
  ConsumerState<CatalogFormScreen> createState() => _CatalogFormScreenState();
}

class _CatalogFormScreenState extends ConsumerState<CatalogFormScreen> {
  late final _name = TextEditingController(text: widget.edit?.name ?? '');
  late final _desc = TextEditingController(
    text: widget.edit?.description ?? '',
  );
  late final _country = TextEditingController(text: widget.edit?.country ?? '');
  late final _cc = TextEditingController(text: widget.edit?.engineCc ?? '');
  late final _year = TextEditingController(
    text: widget.edit?.year?.toString() ?? '',
  );
  late final _price = TextEditingController(
    text: (widget.edit?.suggestedPrice ?? 0) > 0
        ? _trim(widget.edit!.suggestedPrice!)
        : '',
  );
  late int? _motoBrandId = widget.edit?.motoBrandId;
  late bool _active = widget.edit?.active ?? true;
  bool _saving = false;

  CatalogType get type => widget.type;

  @override
  void dispose() {
    for (final c in [_name, _desc, _country, _cc, _year, _price]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      AppToast.error(context, 'El nombre es obligatorio.');
      return;
    }
    if (type == CatalogType.motoModels && _motoBrandId == null) {
      AppToast.error(context, 'Elige la marca de la moto.');
      return;
    }
    final extra = <String, dynamic>{
      if (type == CatalogType.categories || type == CatalogType.brands)
        'description': _desc.text.trim().isEmpty ? null : _desc.text.trim(),
      if (type == CatalogType.motoBrands)
        'country': _country.text.trim().isEmpty ? null : _country.text.trim(),
      if (type == CatalogType.motoModels) ...{
        'moto_brand_id': _motoBrandId,
        'engine_cc': _cc.text.trim().isEmpty ? null : _cc.text.trim(),
        'year': int.tryParse(_year.text.trim()),
        'suggested_price': double.tryParse(_price.text.replaceAll(',', '.')),
      },
    };
    setState(() => _saving = true);
    try {
      final repo = ref.read(catalogsRepositoryProvider);
      if (widget.edit != null) {
        await repo.update(
          type,
          widget.edit!.id,
          name: name,
          active: _active,
          extra: extra,
        );
      } else {
        await repo.create(type, name: name, extra: extra);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.apiError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.edit != null;
    InputDecoration dec(String label, {String? hint}) => InputDecoration(
      labelText: label,
      hintText: hint,
      border: const OutlineInputBorder(),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '${isEdit ? 'Editar' : 'Nuev${_fem ? 'a' : 'o'}'} ${type.singular.toLowerCase()}',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (type == CatalogType.motoModels) ...[
            _MotoBrandPicker(
              value: _motoBrandId,
              onChanged: (v) => setState(() => _motoBrandId = v),
            ),
            const SizedBox(height: 12),
          ],
          TextField(
            textCapitalization: TextCapitalization.characters,
            inputFormatters: upperCaseFormatters,
            controller: _name,
            decoration: dec('Nombre *'),
          ),
          if (type == CatalogType.categories || type == CatalogType.brands) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _desc,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: dec('Descripción'),
            ),
          ],
          if (type == CatalogType.motoBrands) ...[
            const SizedBox(height: 12),
            TextField(
              textCapitalization: TextCapitalization.characters,
              inputFormatters: upperCaseFormatters,
              controller: _country,
              decoration: dec('País', hint: 'Ej: JAPÓN'),
            ),
          ],
          if (type == CatalogType.motoModels) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _cc,
                    decoration: dec('Cilindrada', hint: '150cc'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _year,
                    keyboardType: TextInputType.number,
                    decoration: dec('Año'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Precio sugerido',
                prefixText: '$currencySymbol ',
                border: const OutlineInputBorder(),
              ),
            ),
          ],
          if (isEdit) ...[
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activo'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
          ],
          const SizedBox(height: 12),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(50),
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

  bool get _fem =>
      type == CatalogType.categories ||
      type == CatalogType.brands ||
      type == CatalogType.motoBrands;

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}

/// Desplegable de marcas de moto (para el modelo), con alta rápida.
class _MotoBrandPicker extends ConsumerWidget {
  final int? value;
  final ValueChanged<int?> onChanged;
  const _MotoBrandPicker({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(catalogListProvider(CatalogType.motoBrands));
    return async.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text('$e', style: const TextStyle(color: Colors.red)),
      data: (brands) {
        final active = brands.where((b) => b.active || b.id == value).toList();
        return Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<int>(
                key: ValueKey('moto-brand-${active.length}'),
                initialValue: active.any((b) => b.id == value) ? value : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Marca de moto *',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final b in active)
                    DropdownMenuItem(value: b.id, child: Text(b.name)),
                ],
                onChanged: onChanged,
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Nueva marca de moto',
              icon: const Icon(Icons.add),
              onPressed: () async {
                final saved = await Navigator.of(context).push<bool>(
                  MaterialPageRoute(
                    builder: (_) =>
                        const CatalogFormScreen(type: CatalogType.motoBrands),
                  ),
                );
                if (saved == true) {
                  ref.invalidate(catalogListProvider(CatalogType.motoBrands));
                }
              },
            ),
          ],
        );
      },
    );
  }
}
