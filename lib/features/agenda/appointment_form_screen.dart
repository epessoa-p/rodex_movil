import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/app_toast.dart';
import '../../core/models.dart';
import '../../core/sheet_focus.dart';
import '../clients/clients_screen.dart';
import '../workshop/workshop_repository.dart';
import 'agenda_repository.dart';

/// Alta / edición de una cita. Cliente registrado (con vehículo) o rápido
/// (nombre + teléfono), servicio, mecánico, fecha/hora, duración y notas.
class AppointmentFormScreen extends ConsumerStatefulWidget {
  final DateTime date;
  final Appointment? edit;
  const AppointmentFormScreen({super.key, required this.date, this.edit});

  @override
  ConsumerState<AppointmentFormScreen> createState() =>
      _AppointmentFormScreenState();
}

class _AppointmentFormScreenState extends ConsumerState<AppointmentFormScreen> {
  bool _registered = true;

  // Cliente registrado
  int? _clientId;
  String? _clientName;
  List<VehicleOption> _vehicles = [];
  int? _vehicleId;

  // Cliente rápido
  final _name = TextEditingController();
  final _phone = TextEditingController();

  /// Servicios elegidos (varios), en el orden en que se agregaron.
  final List<IdName> _services = [];
  int? _mechanicId;
  final _title = TextEditingController();
  final _notes = TextEditingController();

  late DateTime _date = widget.date;
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  int _duration = 60;

  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      _registered = e.clientId != null;
      _clientId = e.clientId;
      _clientName = e.clientId != null ? e.displayName : null;
      _vehicleId = e.vehicleId;
      _name.text = e.customerName ?? '';
      _phone.text = e.customerPhone ?? '';
      _services.addAll(e.services);
      _mechanicId = e.mechanicId;
      _title.text = e.title ?? '';
      _notes.text = e.notes ?? '';
      _duration = e.durationMinutes;
      final parts = e.date.split('-');
      if (parts.length == 3) {
        _date = DateTime(
          int.parse(parts[0]),
          int.parse(parts[1]),
          int.parse(parts[2]),
        );
      }
      final t = e.time.split(':');
      if (t.length == 2) {
        _time = TimeOfDay(hour: int.parse(t[0]), minute: int.parse(t[1]));
      }
      if (_clientId != null) _loadVehicles(_clientId!, keep: true);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    _title.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadVehicles(int clientId, {bool keep = false}) async {
    try {
      final vs = await ref.read(workshopRepositoryProvider).vehicles(clientId);
      if (mounted) {
        setState(() {
          _vehicles = vs;
          if (!keep) _vehicleId = null;
        });
      }
    } on ApiException {
      // sin vehículos: se puede agendar sin especificar
    }
  }

  Future<void> _pickClient() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientsScreen(
          onPick: (c) {
            Navigator.pop(context);
            setState(() {
              _clientId = c.id;
              _clientName = c.fullName;
            });
            _loadVehicles(c.id);
          },
        ),
      ),
    );
  }

  String get _dateLabel =>
      '${_date.day.toString().padLeft(2, '0')}/${_date.month.toString().padLeft(2, '0')}/${_date.year}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  /// Hoja para elegir servicios del catálogo (varios, con buscador).
  Future<void> _pickServices(List<IdName> catalog) async {
    final picked = await showModalBottomSheet<List<IdName>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ServicesPickerSheet(
        catalog: catalog,
        selected: _services.map((s) => s.id).toSet(),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _services
        ..clear()
        ..addAll(picked);
      if (_title.text.trim().isEmpty && picked.isNotEmpty) {
        _title.text = picked.map((s) => s.name).join(', ');
      }
    });
  }

  Future<void> _save() async {
    if (_registered && _clientId == null) {
      AppToast.error(
        context,
        'Elige un cliente o usa el modo rápido.',
        title: 'Falta el cliente',
      );
      return;
    }
    if (!_registered && _name.text.trim().isEmpty) {
      AppToast.error(
        context,
        'Escribe el nombre del cliente.',
        title: 'Falta el nombre',
      );
      return;
    }

    final hh = _time.hour.toString().padLeft(2, '0');
    final mm = _time.minute.toString().padLeft(2, '0');
    final scheduledAt =
        '${_date.year.toString().padLeft(4, '0')}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')} $hh:$mm:00';

    final body = <String, dynamic>{
      'scheduled_at': scheduledAt,
      'duration_minutes': _duration,
      if (_registered) 'client_id': _clientId,
      if (_registered && _vehicleId != null) 'vehicle_id': _vehicleId,
      if (!_registered) 'customer_name': _name.text.trim(),
      if (!_registered && _phone.text.trim().isNotEmpty)
        'customer_phone': _phone.text.trim(),
      // Siempre se manda (vacío = sin servicios) para que el backend sincronice.
      'service_ids': [for (final s in _services) s.id],
      if (_mechanicId != null) 'mechanic_id': _mechanicId,
      if (_title.text.trim().isNotEmpty) 'title': _title.text.trim(),
      if (_notes.text.trim().isNotEmpty) 'notes': _notes.text.trim(),
    };

    setState(() => _saving = true);
    try {
      final repo = ref.read(agendaRepositoryProvider);
      if (widget.edit != null) {
        await repo.update(widget.edit!.id, body);
      } else {
        await repo.create(body);
      }
      if (mounted) {
        AppToast.success(
          context,
          widget.edit != null ? 'Cita actualizada.' : 'Cita agendada.',
        );
        Navigator.pop(context, true);
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.apiError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final metaAsync = ref.watch(appointmentMetaProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.edit != null ? 'Editar cita' : 'Nueva cita'),
      ),
      body: metaAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (meta) => ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Tipo de cliente
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(
                  value: true,
                  label: Text('Registrado'),
                  icon: Icon(Icons.person_outline),
                ),
                ButtonSegment(
                  value: false,
                  label: Text('Rápido'),
                  icon: Icon(Icons.person_add_alt),
                ),
              ],
              selected: {_registered},
              onSelectionChanged: (s) => setState(() => _registered = s.first),
            ),
            const SizedBox(height: 12),

            if (_registered) ...[
              Card(
                child: ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: Text(_clientName ?? 'Elegir cliente'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: _pickClient,
                ),
              ),
              if (_vehicles.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: DropdownButtonFormField<int?>(
                    initialValue: _vehicleId,
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Vehículo',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('— Sin especificar —'),
                      ),
                      for (final v in _vehicles)
                        DropdownMenuItem(
                          value: v.id,
                          child: Text(
                            v.plate != null && v.plate!.isNotEmpty
                                ? '${v.label} · ${v.plate}'
                                : v.label,
                          ),
                        ),
                    ],
                    onChanged: (v) => setState(() => _vehicleId = v),
                  ),
                ),
            ] else ...[
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                  labelText: 'Nombre del cliente *',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Teléfono (opcional)',
                  helperText: 'Con nombre y teléfono se registra como cliente.',
                  border: OutlineInputBorder(),
                ),
              ),
            ],

            const SizedBox(height: 16),
            // Servicios (varios): chips + botón para agregar desde el catálogo.
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.handyman_outlined,
                          size: 18,
                          color: Colors.black54,
                        ),
                        const SizedBox(width: 6),
                        const Expanded(
                          child: Text(
                            'Servicios',
                            style: TextStyle(fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () => _pickServices(meta.services),
                          icon: const Icon(Icons.add, size: 18),
                          label: Text(
                            _services.isEmpty ? 'Agregar servicio' : 'Agregar',
                          ),
                        ),
                      ],
                    ),
                    if (_services.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(top: 2, bottom: 4),
                        child: Text(
                          'Sin especificar. Puedes elegir varios.',
                          style: TextStyle(fontSize: 12, color: Colors.black54),
                        ),
                      )
                    else
                      Wrap(
                        spacing: 6,
                        runSpacing: -4,
                        children: [
                          for (final s in _services)
                            InputChip(
                              label: Text(s.name),
                              onDeleted: () =>
                                  setState(() => _services.remove(s)),
                            ),
                        ],
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _mechanicId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Mecánico',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(value: null, child: Text('Sin asignar')),
                for (final m in meta.mechanics)
                  DropdownMenuItem(value: m.id, child: Text(m.name)),
              ],
              onChanged: (v) => setState(() => _mechanicId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                labelText: 'Motivo / detalle',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.event_outlined),
                    label: Text(_dateLabel),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
                    icon: const Icon(Icons.schedule_outlined),
                    label: Text(_time.format(context)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: _duration,
              decoration: const InputDecoration(
                labelText: 'Duración',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 30, child: Text('30 min')),
                DropdownMenuItem(value: 60, child: Text('1 hora')),
                DropdownMenuItem(value: 90, child: Text('1 h 30 min')),
                DropdownMenuItem(value: 120, child: Text('2 horas')),
                DropdownMenuItem(value: 180, child: Text('3 horas')),
                DropdownMenuItem(value: 240, child: Text('4 horas')),
              ],
              onChanged: (v) => setState(() => _duration = v ?? 60),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notes,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
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
              label: const Text('Guardar cita'),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}

/// Hoja de selección múltiple de servicios del catálogo, con buscador.
/// Devuelve la lista elegida (en el orden del catálogo) al confirmar.
class _ServicesPickerSheet extends StatefulWidget {
  final List<IdName> catalog;
  final Set<int> selected;
  const _ServicesPickerSheet({required this.catalog, required this.selected});

  @override
  State<_ServicesPickerSheet> createState() => _ServicesPickerSheetState();
}

class _ServicesPickerSheetState extends State<_ServicesPickerSheet> {
  late final Set<int> _sel = {...widget.selected};
  final _query = TextEditingController();
  // Foco diferido: nunca `autofocus` dentro de una hoja (ANR en MIUI).
  late final SheetFocus _focus = SheetFocus(this);

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.text.trim().toLowerCase();
    final items = q.isEmpty
        ? widget.catalog
        : widget.catalog
              .where((s) => s.name.toLowerCase().contains(q))
              .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * .7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Servicios',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Text(
                      '${_sel.length} elegidos',
                      style: const TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _query,
                  focusNode: _focus.node,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'Buscar servicio…',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    border: const OutlineInputBorder(),
                    suffixIcon: q.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(_query.clear),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Expanded(
                child: items.isEmpty
                    ? const Center(
                        child: Text(
                          'Sin resultados.',
                          style: TextStyle(color: Colors.black54),
                        ),
                      )
                    : ListView.builder(
                        itemCount: items.length,
                        itemBuilder: (_, i) {
                          final s = items[i];
                          return CheckboxListTile(
                            dense: true,
                            controlAffinity: ListTileControlAffinity.leading,
                            title: Text(s.name),
                            value: _sel.contains(s.id),
                            onChanged: (v) => setState(() {
                              if (v == true) {
                                _sel.add(s.id);
                              } else {
                                _sel.remove(s.id);
                              }
                            }),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(46),
                  ),
                  icon: const Icon(Icons.check),
                  label: Text(
                    _sel.isEmpty ? 'Sin servicios' : 'Listo (${_sel.length})',
                  ),
                  onPressed: () => Navigator.pop(context, [
                    for (final s in widget.catalog)
                      if (_sel.contains(s.id)) s,
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
