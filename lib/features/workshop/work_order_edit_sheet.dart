import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/app_toast.dart';
import '../../core/models.dart';
import '../../core/upper_case.dart';
import '../clients/clients_screen.dart';
import 'workshop_repository.dart';

/// Edita los datos de una OT en curso: kilometraje, combustible, falla
/// reportada, "recibido con" y notas. Si la OT no tiene cliente (servicio
/// rápido) permite asignarlo y elegir su vehículo, o dejar el texto libre.
/// Devuelve la OT actualizada al cerrarse.
class WorkOrderEditSheet extends ConsumerStatefulWidget {
  final WorkOrder order;
  const WorkOrderEditSheet({super.key, required this.order});

  @override
  ConsumerState<WorkOrderEditSheet> createState() => _WorkOrderEditSheetState();
}

class _WorkOrderEditSheetState extends ConsumerState<WorkOrderEditSheet> {
  late final _mileage = TextEditingController(
    text: widget.order.mileage?.toString() ?? '',
  );
  late final _fuel = TextEditingController(text: widget.order.fuelLevel ?? '');
  late final _issue = TextEditingController(
    text: widget.order.reportedIssue ?? '',
  );
  late final _received = TextEditingController(
    text: widget.order.receivedItems ?? '',
  );
  late final _notes = TextEditingController(text: widget.order.notes ?? '');
  late final _vehicleText = TextEditingController(
    text: widget.order.vehicle ?? '',
  );

  Client? _client;
  List<VehicleOption> _vehicles = [];
  int? _vehicleId;
  bool _saving = false;

  /// Sin cliente registrado (servicio rápido): se puede asignar uno.
  bool get _canAssignClient => widget.order.client == null;

  @override
  void dispose() {
    for (final c in [
      _mileage,
      _fuel,
      _issue,
      _received,
      _notes,
      _vehicleText,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _pickClient() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ClientsScreen(
          onPick: (c) async {
            Navigator.pop(context);
            setState(() {
              _client = c;
              _vehicleId = null;
              _vehicles = [];
            });
            try {
              final vs = await ref
                  .read(workshopRepositoryProvider)
                  .vehicles(c.id);
              if (mounted) setState(() => _vehicles = vs);
            } on ApiException {
              // sin vehículos: queda el texto libre
            }
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final updated = await ref
          .read(workshopRepositoryProvider)
          .updateOrder(
            widget.order.id,
            clientId: _client?.id,
            vehicleId: _vehicleId,
            quickVehicle: _canAssignClient && _vehicleId == null
                ? (_vehicleText.text.trim().isEmpty
                      ? null
                      : _vehicleText.text.trim())
                : null,
            mileage: int.tryParse(_mileage.text.trim()),
            fuelLevel: _fuel.text.trim().isEmpty ? null : _fuel.text.trim(),
            reportedIssue: _issue.text.trim().isEmpty
                ? null
                : _issue.text.trim(),
            receivedItems: _received.text.trim().isEmpty
                ? null
                : _received.text.trim(),
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (mounted) Navigator.pop(context, updated);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.apiError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Editar ${widget.order.code}',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 12),
            if (_canAssignClient) ...[
              InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: _saving ? null : _pickClient,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Cliente (opcional)',
                    hintText: 'Cliente de paso',
                    border: const OutlineInputBorder(),
                    suffixIcon: _client == null
                        ? const Icon(Icons.search)
                        : IconButton(
                            tooltip: 'Quitar',
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(() {
                              _client = null;
                              _vehicles = [];
                              _vehicleId = null;
                            }),
                          ),
                  ),
                  isEmpty: _client == null,
                  child: Text(
                    _client?.fullName ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              if (_vehicles.isNotEmpty)
                DropdownButtonFormField<int?>(
                  key: ValueKey('veh-${_client?.id}-${_vehicles.length}'),
                  initialValue: _vehicleId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: 'Vehículo del cliente',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('Sin vehículo'),
                    ),
                    for (final v in _vehicles)
                      DropdownMenuItem(value: v.id, child: Text(v.label)),
                  ],
                  onChanged: (v) => setState(() => _vehicleId = v),
                )
              else
                TextField(
                  controller: _vehicleText,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: upperCaseFormatters,
                  decoration: const InputDecoration(
                    labelText: 'Vehículo (texto libre)',
                    border: OutlineInputBorder(),
                  ),
                ),
              const SizedBox(height: 10),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mileage,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Kilometraje',
                      suffixText: 'km',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _fuel,
                    decoration: const InputDecoration(
                      labelText: 'Combustible',
                      hintText: '1/2',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _issue,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Falla reportada',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _received,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Recibido con',
                hintText: 'Casco, herramientas…',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              maxLines: 2,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notas',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
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
              label: const Text('Guardar cambios'),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
