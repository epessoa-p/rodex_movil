import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../clients/clients_screen.dart';
import 'workshop_repository.dart';

/// Recepción: alta de una orden de trabajo (cliente + vehículo + falla).
/// Puede venir precargada desde una cita de la agenda (con el cliente ya
/// elegido); en ese caso se enlaza la cita al crear la OT.
class ReceptionScreen extends ConsumerStatefulWidget {
  final Client? prefillClient;
  final int? appointmentId;
  final String? prefillIssue;
  const ReceptionScreen({
    super.key,
    this.prefillClient,
    this.appointmentId,
    this.prefillIssue,
  });

  @override
  ConsumerState<ReceptionScreen> createState() => _ReceptionScreenState();
}

class _ReceptionScreenState extends ConsumerState<ReceptionScreen> {
  Client? _client;
  bool _newVehicle = true;

  // Vehículo existente
  List<VehicleOption> _vehicles = [];
  int? _vehicleId;

  // Vehículo nuevo
  final _brand = TextEditingController();
  final _model = TextEditingController();
  final _plate = TextEditingController();
  final _year = TextEditingController();
  final _color = TextEditingController();

  final _issue = TextEditingController();
  final _mileage = TextEditingController();
  final _fuel = TextEditingController();
  final _received = TextEditingController();
  final _notes = TextEditingController();
  DateTime _receptionDate = DateTime.now();

  // Mecánico (opcional)
  List<Mechanic> _mechanics = [];
  int? _mechanicId;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadMechanics();
    if (widget.prefillIssue != null) _issue.text = widget.prefillIssue!;
    final c = widget.prefillClient;
    if (c != null) {
      _client = c;
      // Carga los vehículos del cliente; si no tiene, arranca en "nuevo".
      Future.microtask(() async {
        final vs = await ref.read(workshopRepositoryProvider).vehicles(c.id);
        if (mounted) {
          setState(() {
            _vehicles = vs;
            _newVehicle = vs.isEmpty;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    for (final c in [
      _brand, _model, _plate, _year, _color,
      _issue, _mileage, _fuel, _received, _notes,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadMechanics() async {
    try {
      final ms = await ref.read(workshopRepositoryProvider).mechanics();
      if (mounted) setState(() => _mechanics = ms);
    } on ApiException {
      // sin mecánicos: el campo queda vacío (es opcional)
    }
  }

  Future<void> _pickClient() async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ClientsScreen(
        onPick: (c) async {
          Navigator.pop(context);
          setState(() {
            _client = c;
            _vehicleId = null;
            _vehicles = [];
          });
          // Cargar vehículos del cliente
          final vs = await ref.read(workshopRepositoryProvider).vehicles(c.id);
          if (mounted) {
            setState(() {
              _vehicles = vs;
              _newVehicle = vs.isEmpty; // si no tiene, arranca en "nuevo"
            });
          }
        },
      ),
    ));
  }

  Future<void> _submit() async {
    if (_client == null) {
      _snack('Elige un cliente.');
      return;
    }
    if (!_newVehicle && _vehicleId == null) {
      _snack('Elige un vehículo o registra uno nuevo.');
      return;
    }
    if (_newVehicle && _brand.text.trim().isEmpty) {
      _snack('La marca del vehículo es obligatoria.');
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(workshopRepositoryProvider).createReception(
            clientId: _client!.id,
            mechanicId: _mechanicId,
            vehicleId: _newVehicle ? null : _vehicleId,
            receptionDate: _fmtDate(_receptionDate),
            newVehicle: _newVehicle
                ? {
                    'brand': _brand.text.trim(),
                    'model': _model.text.trim(),
                    'plate': _plate.text.trim(),
                    if (int.tryParse(_year.text) != null)
                      'year': int.parse(_year.text),
                    if (_color.text.trim().isNotEmpty)
                      'color': _color.text.trim(),
                  }
                : null,
            reportedIssue:
                _issue.text.trim().isEmpty ? null : _issue.text.trim(),
            mileage: int.tryParse(_mileage.text),
            fuelLevel: _fuel.text.trim().isEmpty ? null : _fuel.text.trim(),
            receivedItems:
                _received.text.trim().isEmpty ? null : _received.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
            appointmentId: widget.appointmentId,
          );
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _submitting = false);
        _snack(e.message);
      }
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  /// Formato para el API (YYYY-MM-DD).
  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _receptionDate,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      helpText: 'Fecha de recepción',
    );
    if (picked != null) setState(() => _receptionDate = picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nueva orden de trabajo')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Cliente
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(_client?.fullName ?? 'Elegir cliente *'),
              trailing: const Icon(Icons.chevron_right),
              onTap: _pickClient,
            ),
          ),
          const SizedBox(height: 8),

          // Fecha de recepción (por defecto hoy)
          Card(
            child: ListTile(
              leading: const Icon(Icons.event_outlined),
              title: const Text('Fecha de recepción'),
              subtitle: Text(_fmtDate(_receptionDate)),
              trailing: const Icon(Icons.edit_calendar_outlined),
              onTap: _pickDate,
            ),
          ),
          const SizedBox(height: 16),

          // Vehículo
          Text('Vehículo', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          SegmentedButton<bool>(
            segments: const [
              ButtonSegment(value: false, label: Text('Existente')),
              ButtonSegment(value: true, label: Text('Nuevo')),
            ],
            selected: {_newVehicle},
            onSelectionChanged: _client == null
                ? null
                : (s) => setState(() => _newVehicle = s.first),
          ),
          const SizedBox(height: 12),
          if (!_newVehicle)
            if (_vehicles.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text('Este cliente no tiene vehículos registrados.'),
              )
            else
              Column(
                children: [
                  for (final v in _vehicles)
                    Card(
                      child: ListTile(
                        leading: Icon(_vehicleId == v.id
                            ? Icons.radio_button_checked
                            : Icons.radio_button_unchecked),
                        title: Text(v.label),
                        subtitle: v.plate != null ? Text(v.plate!) : null,
                        onTap: () => setState(() => _vehicleId = v.id),
                      ),
                    ),
                ],
              )
          else
            Column(
              children: [
                TextField(
                  controller: _brand,
                  decoration: const InputDecoration(labelText: 'Marca *'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _model,
                  decoration: const InputDecoration(labelText: 'Modelo'),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _plate,
                  decoration: const InputDecoration(labelText: 'Placa'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _year,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(labelText: 'Año'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _color,
                        decoration: const InputDecoration(labelText: 'Color'),
                      ),
                    ),
                  ],
                ),
              ],
            ),

          const SizedBox(height: 16),
          DropdownButtonFormField<int?>(
            initialValue: _mechanicId,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: 'Mecánico',
              prefixIcon: const Icon(Icons.engineering_outlined),
              helperText: _mechanics.isEmpty
                  ? 'No hay mecánicos registrados (créalos en la web).'
                  : null,
            ),
            items: [
              const DropdownMenuItem(value: null, child: Text('Sin asignar')),
              for (final m in _mechanics)
                DropdownMenuItem(value: m.id, child: Text(m.name)),
            ],
            onChanged: (v) => setState(() => _mechanicId = v),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _issue,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Falla reportada',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _mileage,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Kilometraje'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _fuel,
                  decoration:
                      const InputDecoration(labelText: 'Combustible'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _received,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Objetos / accesorios recibidos',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _notes,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Notas',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton.icon(
            icon: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: const Text('Registrar recepción'),
            onPressed: _submitting ? null : _submit,
          ),
        ],
      ),
    );
  }
}
