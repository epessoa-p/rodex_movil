import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/app_toast.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/upper_case.dart';
import '../agenda/agenda_repository.dart';
import '../clients/clients_screen.dart';
import '../payments/widgets/cash_available_hint.dart';
import '../products/products_screen.dart';
import 'service_pick_sheet.dart';
import 'work_order_detail_screen.dart';
import 'workshop_repository.dart';

const _methods = {
  'efectivo': 'Efectivo',
  'transferencia': 'Transferencia',
  'tarjeta': 'Tarjeta',
  'qr': 'QR',
};

/// Servicio rápido: para trabajos al paso (ajuste de cadena, cambio de
/// aceite…). Elige servicios, cobra y listo: se crea la OT ya entregada y
/// pagada. Cliente y vehículo son opcionales.
class QuickServiceScreen extends ConsumerStatefulWidget {
  const QuickServiceScreen({super.key});

  @override
  ConsumerState<QuickServiceScreen> createState() => _QuickServiceScreenState();
}

/// Repuesto elegido del inventario (se descuenta del stock al cobrar).
class _PartPick {
  final Product product;
  final int quantity;
  final double price;
  const _PartPick(this.product, this.quantity, this.price);
  double get subtotal => price * quantity;
}

class _QuickServiceScreenState extends ConsumerState<QuickServiceScreen> {
  final List<ServicePick> _lines = [];
  final List<_PartPick> _parts = [];
  List<Mechanic> _mechanics = [];
  int? _mechanicId;
  Client? _client;
  List<VehicleOption> _vehicles = [];
  int? _vehicleId;
  final _vehicleText = TextEditingController();
  final _discount = TextEditingController();
  final _notes = TextEditingController();
  String _method = 'efectivo';
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadMechanics();
  }

  @override
  void dispose() {
    _vehicleText.dispose();
    _discount.dispose();
    _notes.dispose();
    super.dispose();
  }

  Future<void> _loadMechanics() async {
    try {
      final ms = await ref.read(workshopRepositoryProvider).mechanics();
      if (mounted) setState(() => _mechanics = ms);
    } catch (_) {
      // sin mecánicos: el campo queda vacío (es opcional)
    }
  }

  double get _subtotal =>
      _lines.fold<double>(0, (s, l) => s + l.price * l.quantity) +
      _parts.fold<double>(0, (s, p) => s + p.subtotal);
  double get _discountValue =>
      double.tryParse(_discount.text.replaceAll(',', '.')) ?? 0;
  double get _total => (_subtotal - _discountValue).clamp(0, double.infinity);

  Future<void> _addService() async {
    List<ServiceOption> catalog = const [];
    try {
      catalog = (await ref.read(appointmentMetaProvider.future)).services;
    } catch (_) {
      // sin catálogo: igual se puede escribir el servicio a mano
    }
    if (!mounted) return;
    final picked = await showModalBottomSheet<ServicePick>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddServiceSheet(catalog: catalog),
    );
    if (picked != null) setState(() => _lines.add(picked));
  }

  /// Elige un repuesto del inventario y pide cantidad/precio (como en la OT).
  Future<void> _addPart() async {
    Product? product;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProductsScreen(
          onPick: (p) {
            product = p;
            Navigator.pop(context);
          },
        ),
      ),
    );
    if (product == null || !mounted) return;

    final pick = await showDialog<_PartPick>(
      context: context,
      builder: (_) => _PartQtyDialog(product: product!),
    );
    if (pick != null && mounted) setState(() => _parts.add(pick));
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

  Future<void> _submit() async {
    if (_lines.isEmpty && _parts.isEmpty) {
      AppToast.error(context, 'Agrega al menos un servicio o un repuesto.');
      return;
    }
    setState(() => _saving = true);
    try {
      final order = await ref
          .read(workshopRepositoryProvider)
          .quickService(
            services: [
              for (final l in _lines)
                {
                  'description': l.name,
                  'price': l.price,
                  'quantity': l.quantity,
                },
            ],
            parts: [
              for (final p in _parts)
                {
                  'product_id': p.product.id,
                  'quantity': p.quantity,
                  'unit_price': p.price,
                },
            ],
            mechanicId: _mechanicId,
            clientId: _client?.id,
            vehicleId: _vehicleId,
            quickVehicle: _vehicleText.text.trim().isEmpty
                ? null
                : _vehicleText.text.trim(),
            method: _method,
            discount: _discountValue,
            notes: _notes.text.trim().isEmpty ? null : _notes.text.trim(),
          );
      if (!mounted) return;
      // Los servicios escritos a mano se crearon en el catálogo: refrescarlo.
      ref.invalidate(appointmentMetaProvider);
      AppToast.success(
        context,
        '${order.code} cobrada: ${money(order.total)}.',
        title: 'Servicio rápido registrado',
      );
      // Abre el detalle (para compartir el recibo) en lugar de esta pantalla.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => WorkOrderDetailScreen(orderId: order.id),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.apiError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Servicio rápido')),
      // Columna completa (no ListView perezoso): el aviso de caja invalida
      // su provider al crearse; si se recreara al hacer scroll, repetiría
      // la consulta en cada pasada.
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: cs.tertiaryContainer.withValues(alpha: .5),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bolt, color: Colors.orange),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Para trabajos al paso: se crea la OT, se entrega y se cobra en un solo paso. Cliente y vehículo son opcionales.',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // ── Servicios ──
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Servicios',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                FilledButton.tonalIcon(
                  // El tema da a los FilledButton ancho mínimo infinito (botones
                  // de formulario a lo ancho); dentro de un Row hay que acotarlo.
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: _saving ? null : _addService,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_lines.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Aún no hay servicios. Toca "Agregar" y elige del catálogo o escribe uno.',
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              for (var i = 0; i < _lines.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    title: Text(_lines[i].name),
                    subtitle: Text(
                      '${_lines[i].quantity} × ${money(_lines[i].price)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          money(_lines[i].price * _lines[i].quantity),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          tooltip: 'Quitar',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: _saving
                              ? null
                              : () => setState(() => _lines.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 14),

            // ── Repuestos (descuentan stock al cobrar) ──
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Repuestos',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                FilledButton.tonalIcon(
                  // Igual que "Agregar" de servicios: el tema da ancho mínimo
                  // infinito a FilledButton y dentro de un Row hay que acotarlo.
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 40),
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                  ),
                  onPressed: _saving ? null : _addPart,
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Agregar'),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (_parts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Text(
                  'Sin repuestos. Agrega los que se usaron: se descuentan del stock al cobrar.',
                  style: TextStyle(color: Colors.black54),
                ),
              )
            else
              for (var i = 0; i < _parts.length; i++)
                Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    dense: true,
                    title: Text(
                      _parts[i].product.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${_parts[i].quantity} × ${money(_parts[i].price)}',
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          money(_parts[i].subtotal),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        IconButton(
                          tooltip: 'Quitar',
                          visualDensity: VisualDensity.compact,
                          icon: const Icon(Icons.close, size: 18),
                          onPressed: _saving
                              ? null
                              : () => setState(() => _parts.removeAt(i)),
                        ),
                      ],
                    ),
                  ),
                ),
            const SizedBox(height: 12),

            // ── Mecánico ──
            DropdownButtonFormField<int?>(
              key: ValueKey('mech-${_mechanics.length}'),
              initialValue: _mechanicId,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Mecánico (opcional)',
                border: OutlineInputBorder(),
              ),
              items: [
                const DropdownMenuItem(
                  value: null,
                  child: Text('Sin mecánico'),
                ),
                for (final m in _mechanics)
                  DropdownMenuItem(value: m.id, child: Text(m.name)),
              ],
              onChanged: (v) => setState(() => _mechanicId = v),
            ),
            const SizedBox(height: 12),

            // ── Cliente / vehículo (opcionales) ──
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
            const SizedBox(height: 12),
            if (_vehicles.isNotEmpty) ...[
              DropdownButtonFormField<int?>(
                key: ValueKey('veh-${_client?.id}-${_vehicles.length}'),
                initialValue: _vehicleId,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Vehículo del cliente (opcional)',
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
              ),
            ],
            if (_vehicleId == null)
              TextField(
                controller: _vehicleText,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: upperCaseFormatters,
                decoration: const InputDecoration(
                  labelText: 'Vehículo (texto libre, opcional)',
                  hintText: 'Ej: CG 150 ROJA',
                  border: OutlineInputBorder(),
                ),
              ),
            const SizedBox(height: 16),

            // ── Cobro ──
            const Text(
              'Cobro',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              children: [
                for (final e in _methods.entries)
                  ChoiceChip(
                    label: Text(e.value),
                    selected: _method == e.key,
                    onSelected: (_) => setState(() => _method = e.key),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _discount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: 'Descuento (opcional)',
                prefixText: '$currencySymbol ',
                border: const OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Notas (opcional)',
                border: OutlineInputBorder(),
              ),
            ),
            // Cobro: el dinero entra, así que el saldo de caja no aporta;
            // solo avisa si no hay caja abierta (sin ella no se puede cobrar).
            const CashAvailableHint(incoming: true),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: cs.primaryContainer,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Total a cobrar',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                  Text(
                    money(_total),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
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
                  : const Icon(Icons.bolt),
              label: Text('Cobrar ${money(_total)} y cerrar'),
              onPressed: _saving || (_lines.isEmpty && _parts.isEmpty)
                  ? null
                  : _submit,
            ),
          ],
        ),
      ),
    );
  }
}

/// Cantidad y precio de un repuesto. Tiene sus propios controladores para que
/// se liberen al cerrarse (liberarlos desde fuera rompe la animación de salida).
class _PartQtyDialog extends StatefulWidget {
  final Product product;
  const _PartQtyDialog({required this.product});

  @override
  State<_PartQtyDialog> createState() => _PartQtyDialogState();
}

class _PartQtyDialogState extends State<_PartQtyDialog> {
  late final _qty = TextEditingController(text: '1');
  late final _price = TextEditingController(
    text: widget.product.price.toStringAsFixed(2),
  );

  @override
  void dispose() {
    _qty.dispose();
    _price.dispose();
    super.dispose();
  }

  void _submit() {
    final quantity = int.tryParse(_qty.text.trim()) ?? 1;
    final price =
        double.tryParse(_price.text.trim().replaceAll(',', '.')) ??
        widget.product.price;
    Navigator.pop(
      context,
      _PartPick(widget.product, quantity < 1 ? 1 : quantity, price),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.product.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Stock: ${qty(widget.product.currentStock)} ${widget.product.unit ?? ''}',
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _qty,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Cantidad'),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _price,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Precio unitario',
              prefixText: '$currencySymbol ',
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Agregar')),
      ],
    );
  }
}
