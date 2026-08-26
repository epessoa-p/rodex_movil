import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/models.dart';
import '../clients/clients_screen.dart';
import 'workshop_repository.dart';

/// Recepción: alta de una orden de trabajo (cliente + vehículo + falla).
class ReceptionScreen extends ConsumerStatefulWidget {
  const ReceptionScreen({super.key});

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

  final _issue = TextEditingController();
  final _mileage = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _brand.dispose();
    _model.dispose();
    _plate.dispose();
    _issue.dispose();
    _mileage.dispose();
    super.dispose();
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
            vehicleId: _newVehicle ? null : _vehicleId,
            newVehicle: _newVehicle
                ? {
                    'brand': _brand.text.trim(),
                    'model': _model.text.trim(),
                    'plate': _plate.text.trim(),
                  }
                : null,
            reportedIssue:
                _issue.text.trim().isEmpty ? null : _issue.text.trim(),
            mileage: int.tryParse(_mileage.text),
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
              ],
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
          TextField(
            controller: _mileage,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Kilometraje'),
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
