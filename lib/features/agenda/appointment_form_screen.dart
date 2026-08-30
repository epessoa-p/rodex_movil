import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
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

  int? _serviceId;
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
      _serviceId = e.serviceId;
      _mechanicId = e.mechanicId;
      _title.text = e.title ?? '';
      _notes.text = e.notes ?? '';
      _duration = e.durationMinutes;
      final parts = e.date.split('-');
      if (parts.length == 3) {
        _date = DateTime(
            int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
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
    await Navigator.of(context).push(MaterialPageRoute(
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
    ));
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

  Future<void> _save() async {
    if (_registered && _clientId == null) {
      _snack('Elige un cliente o usa el modo rápido.');
      return;
    }
    if (!_registered && _name.text.trim().isEmpty) {
      _snack('Escribe el nombre del cliente.');
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
      if (_serviceId != null) 'service_id': _serviceId,
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
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(e.message);
      }
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final metaAsync = ref.watch(appointmentMetaProvider);

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.edit != null ? 'Editar cita' : 'Nueva cita')),
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
                    icon: Icon(Icons.person_outline)),
                ButtonSegment(
                    value: false,
                    label: Text('Rápido'),
                    icon: Icon(Icons.person_add_alt)),
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
                        labelText: 'Vehículo', border: OutlineInputBorder()),
                    items: [
                      const DropdownMenuItem(
                          value: null, child: Text('— Sin especificar —')),
                      for (final v in _vehicles)
                        DropdownMenuItem(
                            value: v.id,
                            child: Text(
                                v.plate != null && v.plate!.isNotEmpty
                                    ? '${v.label} · ${v.plate}'
                                    : v.label)),
                    ],
                    onChanged: (v) => setState(() => _vehicleId = v),
                  ),
                ),
            ] else ...[
              TextField(
                controller: _name,
                decoration: const InputDecoration(
                    labelText: 'Nombre del cliente *',
                    border: OutlineInputBorder()),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                    labelText: 'Teléfono (opcional)',
                    border: OutlineInputBorder()),
              ),
            ],

            const SizedBox(height: 16),
            DropdownButtonFormField<int?>(
              initialValue: _serviceId,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Servicio', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('— Sin especificar —')),
                for (final s in meta.services)
                  DropdownMenuItem(value: s.id, child: Text(s.name)),
              ],
              onChanged: (v) => setState(() {
                _serviceId = v;
                if (_title.text.trim().isEmpty && v != null) {
                  _title.text =
                      meta.services.firstWhere((s) => s.id == v).name;
                }
              }),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _mechanicId,
              isExpanded: true,
              decoration: const InputDecoration(
                  labelText: 'Mecánico', border: OutlineInputBorder()),
              items: [
                const DropdownMenuItem(
                    value: null, child: Text('Sin asignar')),
                for (final m in meta.mechanics)
                  DropdownMenuItem(value: m.id, child: Text(m.name)),
              ],
              onChanged: (v) => setState(() => _mechanicId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: const InputDecoration(
                  labelText: 'Motivo / detalle', border: OutlineInputBorder()),
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
                  labelText: 'Duración', border: OutlineInputBorder()),
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
                  labelText: 'Notas (opcional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style:
                  FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
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
