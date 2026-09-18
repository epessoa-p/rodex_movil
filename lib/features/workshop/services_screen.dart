import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/app_toast.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/upper_case.dart';
import '../../core/module_colors.dart';
import '../agenda/agenda_repository.dart';
import 'services_repository.dart';

/// Catálogo de servicios del taller: listado con buscador + alta/edición.
/// Con [embedded] = true es un tab del hub "Taller".
class ServicesScreen extends ConsumerStatefulWidget {
  final bool embedded;
  const ServicesScreen({super.key, this.embedded = false});

  @override
  ConsumerState<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends ConsumerState<ServicesScreen> {
  String _q = '';

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).me;
    final canCreate = me?.can('services.create') ?? false;
    final canEdit = me?.can('services.edit') ?? false;
    final async = ref.watch(servicesCatalogProvider);

    return Scaffold(
      appBar: widget.embedded ? null : AppBar(title: const Text('Servicios')),
      floatingActionButton: canCreate
          ? FloatingActionButton.extended(
              heroTag: 'fab-services',
              backgroundColor: ModuleColors.soft(ModuleColors.services),
              foregroundColor: ModuleColors.onSoft(ModuleColors.services),
              onPressed: () => _openForm(),
              icon: const Icon(Icons.add),
              label: const Text('Nuevo servicio'),
            )
          : null,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
            child: TextField(
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Buscar servicio…',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (v) => setState(() => _q = v.trim().toLowerCase()),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(servicesCatalogProvider),
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
                            .where((s) => s.name.toLowerCase().contains(_q))
                            .toList();
                  if (list.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 80),
                        Center(
                          child: Text(
                            all.isEmpty
                                ? 'Aún no hay servicios. Crea el primero.'
                                : 'Sin resultados para «$_q».',
                          ),
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 88),
                    itemCount: list.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _ServiceTile(
                      s: list[i],
                      onTap: canEdit ? () => _openForm(edit: list[i]) : null,
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openForm({ServiceItem? edit}) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ServiceFormScreen(edit: edit)),
    );
    if (saved == true) {
      ref.invalidate(servicesCatalogProvider);
      // El selector de servicios de la cita y de la OT usa este catálogo.
      ref.invalidate(appointmentMetaProvider);
    }
  }
}

class _ServiceTile extends StatelessWidget {
  final ServiceItem s;
  final VoidCallback? onTap;
  const _ServiceTile({required this.s, this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = s.active ? ModuleColors.services : Colors.grey;
    final extra = [
      if (s.estimatedTime != null && s.estimatedTime!.isNotEmpty)
        s.estimatedTime!,
      if (s.description != null && s.description!.isNotEmpty) s.description!,
      if (!s.active) 'inactivo',
    ].join(' · ');
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withValues(alpha: .15),
          child: Icon(Icons.home_repair_service_outlined, color: color),
        ),
        title: Text(
          s.name,
          style: TextStyle(
            fontWeight: FontWeight.w600,
            color: s.active ? null : Colors.grey,
          ),
        ),
        subtitle: extra.isEmpty ? null : Text(extra),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              money(s.price),
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            if (onTap != null)
              const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Formulario de alta/edición de servicio.
class ServiceFormScreen extends ConsumerStatefulWidget {
  final ServiceItem? edit;
  const ServiceFormScreen({super.key, this.edit});

  @override
  ConsumerState<ServiceFormScreen> createState() => _ServiceFormScreenState();
}

class _ServiceFormScreenState extends ConsumerState<ServiceFormScreen> {
  late final _name = TextEditingController(text: widget.edit?.name ?? '');
  late final _price = TextEditingController(
    text: widget.edit != null ? _trim(widget.edit!.price) : '',
  );
  late final _time = TextEditingController(
    text: widget.edit?.estimatedTime ?? '',
  );
  late final _desc = TextEditingController(
    text: widget.edit?.description ?? '',
  );
  late bool _active = widget.edit?.active ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _price.dispose();
    _time.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final price = double.tryParse(_price.text.replaceAll(',', '.'));
    if (name.isEmpty) {
      _snack('El nombre es obligatorio.');
      return;
    }
    if (price == null || price < 0) {
      _snack('Ingresa un precio válido.');
      return;
    }
    setState(() => _saving = true);
    try {
      final repo = ref.read(servicesRepositoryProvider);
      final desc = _desc.text.trim().isEmpty ? null : _desc.text.trim();
      final time = _time.text.trim().isEmpty ? null : _time.text.trim();
      if (widget.edit != null) {
        await repo.update(
          widget.edit!.id,
          name: name,
          price: price,
          description: desc,
          estimatedTime: time,
          active: _active,
        );
      } else {
        await repo.create(
          name: name,
          price: price,
          description: desc,
          estimatedTime: time,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.apiError(context, e);
      }
    }
  }

  void _snack(String m) => AppToast.error(context, m);

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.edit != null;
    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Editar servicio' : 'Nuevo servicio'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            textCapitalization: TextCapitalization.characters,
            inputFormatters: upperCaseFormatters,
            controller: _name,
            decoration: const InputDecoration(
              labelText: 'Nombre *',
              hintText: 'Ej: CAMBIO DE ACEITE',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Precio *',
              prefixText: '$currencySymbol ',
              helperText: 'Precio de referencia; se puede ajustar en la OT.',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _time,
            decoration: const InputDecoration(
              labelText: 'Tiempo estimado',
              hintText: 'Ej: 30 min, 2 horas',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _desc,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Descripción',
              border: OutlineInputBorder(),
            ),
          ),
          if (isEdit) ...[
            const SizedBox(height: 4),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activo'),
              subtitle: const Text(
                'Inactivo: no aparece al elegir servicios en citas y OTs.',
              ),
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
            label: const Text('Guardar servicio'),
            onPressed: _saving ? null : _save,
          ),
        ],
      ),
    );
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
