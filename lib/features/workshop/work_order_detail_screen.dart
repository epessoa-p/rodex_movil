import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../products/products_screen.dart';
import 'workshop_repository.dart';

class WorkOrderDetailScreen extends ConsumerStatefulWidget {
  final int orderId;
  const WorkOrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<WorkOrderDetailScreen> createState() =>
      _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState
    extends ConsumerState<WorkOrderDetailScreen> {
  WorkOrder? _order;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  WorkshopRepository get _repo => ref.read(workshopRepositoryProvider);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await _repo.order(widget.orderId);
      if (mounted) setState(() { _order = o; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = '$e'; _loading = false; });
    }
  }

  Future<void> _run(Future<WorkOrder> Function() action) async {
    setState(() => _busy = true);
    try {
      final o = await action();
      if (mounted) setState(() { _order = o; _busy = false; });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }

  bool get _closed =>
      _order?.status == 'entregada' || _order?.status == 'anulada';

  Future<void> _addService() async {
    final desc = TextEditingController();
    final price = TextEditingController();
    final qty = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Agregar servicio'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: desc,
              decoration: const InputDecoration(labelText: 'Descripción *')),
          const SizedBox(height: 8),
          TextField(
              controller: price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration:
                  const InputDecoration(labelText: 'Precio *', prefixText: 'Bs ')),
          const SizedBox(height: 8),
          TextField(
              controller: qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Agregar')),
        ],
      ),
    );
    if (ok != true || desc.text.trim().isEmpty) return;
    await _run(() => _repo.addService(
          widget.orderId,
          description: desc.text.trim(),
          price: double.tryParse(price.text) ?? 0,
          quantity: int.tryParse(qty.text) ?? 1,
        ));
  }

  Future<void> _addPart() async {
    Product? product;
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => ProductsScreen(onPick: (p) {
        product = p;
        Navigator.pop(context);
      }),
    ));
    if (product == null || !mounted) return;

    final qty = TextEditingController(text: '1');
    final price =
        TextEditingController(text: product!.price.toStringAsFixed(2));
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product!.name),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(
              controller: qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad')),
          const SizedBox(height: 8),
          TextField(
              controller: price,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                  labelText: 'Precio unitario', prefixText: 'Bs ')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Agregar')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => _repo.addPart(
          widget.orderId,
          productId: product!.id,
          quantity: int.tryParse(qty.text) ?? 1,
          unitPrice: double.tryParse(price.text) ?? product!.price,
        ));
  }

  Future<void> _deliver() async {
    final to = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entregar y cobrar'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          Text('Total a cobrar: ${money(_order!.total)}'),
          const SizedBox(height: 8),
          TextField(
              controller: to,
              decoration:
                  const InputDecoration(labelText: 'Entregado a (opcional)')),
        ]),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cobrar y entregar')),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() => _repo.deliver(widget.orderId,
        deliveredTo: to.text.trim().isEmpty ? null : to.text.trim()));
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _order == null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error ?? 'No encontrada')),
      );
    }
    final o = _order!;

    return Scaffold(
      appBar: AppBar(title: Text(o.code)),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(o),
              const SizedBox(height: 16),

              _diagnosisSection(o),
              const SizedBox(height: 8),

              _section('Servicios', o.services.isEmpty
                  ? [const ListTile(dense: true, title: Text('Sin servicios'))]
                  : [
                      for (final s in o.services)
                        ListTile(
                          dense: true,
                          title: Text(s.description),
                          subtitle: Text(
                              '${s.quantity} x ${money(s.price)}${s.mechanic != null ? ' · ${s.mechanic}' : ''}'),
                          trailing: Text(money(s.subtotal)),
                        ),
                    ]),
              if (!_closed)
                TextButton.icon(
                    onPressed: _busy ? null : _addService,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar servicio')),

              const SizedBox(height: 8),
              _section('Repuestos', o.parts.isEmpty
                  ? [const ListTile(dense: true, title: Text('Sin repuestos'))]
                  : [
                      for (final p in o.parts)
                        ListTile(
                          dense: true,
                          title: Text(p.name),
                          subtitle:
                              Text('${p.quantity} x ${money(p.unitPrice)}'),
                          trailing: Text(money(p.subtotal)),
                        ),
                    ]),
              if (!_closed)
                TextButton.icon(
                    onPressed: _busy ? null : _addPart,
                    icon: const Icon(Icons.add),
                    label: const Text('Agregar repuesto')),

              const SizedBox(height: 16),
              _totals(o),
              const SizedBox(height: 16),
              if (!_closed) _actions(o),
            ],
          ),
          if (_busy)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x22000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Widget _header(WorkOrder o) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(o.statusLabel,
                  style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              Text('Cliente: ${o.client ?? '-'}'),
              Text('Vehículo: ${o.vehicle ?? '-'}'),
              if (o.mechanic != null && o.mechanic!.isNotEmpty)
                Text('Mecánico: ${o.mechanic}'),
              _recepLine('Kilometraje',
                  o.mileage != null ? '${o.mileage}' : null),
              _recepLine('Combustible', o.fuelLevel),
              _recepLine('Falla reportada', o.reportedIssue),
              _recepLine('Objetos / accesorios', o.receivedItems),
              _recepLine('Notas', o.notes),
            ],
          ),
        ),
      );

  /// Línea de recepción: solo se muestra si hay valor.
  Widget _recepLine(String label, String? value) {
    if (value == null || value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text('$label: $value',
          style: const TextStyle(color: Colors.black54)),
    );
  }

  Widget _diagnosisSection(WorkOrder o) {
    final has = o.diagnosis != null && o.diagnosis!.trim().isNotEmpty;
    return _section('Diagnóstico', [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(has ? o.diagnosis! : 'Sin diagnóstico registrado.',
                style: TextStyle(color: has ? null : Colors.black54)),
            if (!_closed) ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _busy ? null : () => _editDiagnosis(o),
                icon: const Icon(Icons.edit_note),
                label: Text(has ? 'Editar diagnóstico' : 'Agregar diagnóstico'),
              ),
            ],
          ],
        ),
      ),
    ]);
  }

  Future<void> _editDiagnosis(WorkOrder o) async {
    final ctrl = TextEditingController(text: o.diagnosis ?? '');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Diagnóstico'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
              hintText: 'Diagnóstico técnico…', border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Guardar')),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final text = ctrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Escribe el diagnóstico.')));
      return;
    }
    await _run(() => _repo.saveDiagnosis(o.id, text));
  }

  Widget _section(String title, List<Widget> children) => Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(title,
                  style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
            ...children,
            const SizedBox(height: 6),
          ],
        ),
      );

  Widget _totals(WorkOrder o) => Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            _row('Servicios', o.subtotalServices),
            _row('Repuestos', o.subtotalParts),
            if (o.discount > 0) _row('Descuento', -o.discount),
            const Divider(),
            _row('Total', o.total, bold: true),
            if (o.paidAmount > 0) _row('Pagado', o.paidAmount),
            if (o.balance > 0) _row('Saldo', o.balance),
          ]),
        ),
      );

  Widget _row(String k, double v, {bool bold = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(k,
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.normal)),
            Text(money(v),
                style: TextStyle(
                    fontWeight: bold ? FontWeight.w800 : FontWeight.normal)),
          ],
        ),
      );

  Widget _actions(WorkOrder o) {
    // Siguiente estado según el actual.
    final next = switch (o.status) {
      'recibida' => 'diagnosticada',
      'diagnosticada' => 'en_proceso',
      'en_proceso' => 'terminada',
      _ => null,
    };
    final label = switch (next) {
      'diagnosticada' => 'Marcar diagnosticada',
      'en_proceso' => 'Marcar en proceso',
      'terminada' => 'Marcar terminada',
      _ => null,
    };

    return Column(
      children: [
        if (next != null && label != null)
          OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48)),
            icon: const Icon(Icons.arrow_forward),
            label: Text(label),
            onPressed: _busy ? null : () => _run(() => _repo.changeStatus(o.id, next)),
          ),
        const SizedBox(height: 8),
        FilledButton.icon(
          icon: const Icon(Icons.check_circle_outline),
          label: const Text('Entregar y cobrar'),
          onPressed: (_busy || o.total <= 0) ? null : _deliver,
        ),
        if (o.total <= 0)
          const Padding(
            padding: EdgeInsets.only(top: 6),
            child: Text('Agrega servicios o repuestos para poder cobrar.',
                style: TextStyle(fontSize: 12, color: Colors.black54)),
          ),
      ],
    );
  }
}
