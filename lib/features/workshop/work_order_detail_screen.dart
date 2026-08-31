import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/api_client.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../products/products_screen.dart';
import 'work_order_pdf.dart';
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
      appBar: AppBar(
        title: Text(o.code),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Compartir',
            icon: const Icon(Icons.share_outlined),
            enabled: !_busy,
            onSelected: (v) =>
                v == 'receipt' ? _shareReceipt() : _shareTracking(),
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: 'receipt',
                child: ListTile(
                    leading: Icon(Icons.picture_as_pdf_outlined),
                    title: Text('Compartir recibo (PDF)')),
              ),
              PopupMenuItem(
                value: 'tracking',
                child: ListTile(
                    leading: Icon(Icons.link),
                    title: Text('Compartir seguimiento (link)')),
              ),
            ],
          ),
        ],
      ),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _header(o),
              const SizedBox(height: 16),

              _photosSection(o),
              const SizedBox(height: 8),

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

  final _picker = ImagePicker();

  Future<void> _shareTracking() async {
    final o = _order;
    if (o == null) return;
    setState(() => _busy = true);
    try {
      final url = await _repo.shareLink(o.id);
      if (!mounted) return;
      setState(() => _busy = false);
      final veh = o.vehicle != null ? ' (${o.vehicle})' : '';
      await SharePlus.instance.share(ShareParams(
        text: 'Sigue el estado de tu orden ${o.code}$veh aquí:\n$url',
      ));
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(e.message);
      }
    }
  }

  Future<void> _shareReceipt() async {
    final o = _order;
    if (o == null) return;
    setState(() => _busy = true);
    try {
      final company = ref.read(authControllerProvider).me?.company?.name;
      final bytes = await buildWorkOrderPdf(o, company: company);
      if (!mounted) return;
      setState(() => _busy = false);
      await Printing.sharePdf(bytes: bytes, filename: '${o.code}.pdf');
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('No se pudo generar el PDF: $e');
      }
    }
  }

  Future<void> _reloadOrder() async {
    final o = await _repo.order(widget.orderId);
    if (mounted) setState(() { _order = o; _busy = false; });
  }

  Future<void> _assignMechanic() async {
    List<Mechanic> mechs;
    try {
      mechs = await _repo.mechanics();
    } on ApiException catch (e) {
      _snack(e.message);
      return;
    }
    if (!mounted) return;
    if (mechs.isEmpty) {
      _snack('No hay mecánicos. Créalos en Mecánicos.');
      return;
    }
    final current = _order?.mechanic;
    final picked = await showModalBottomSheet<int>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.person_off_outlined),
              title: const Text('Sin asignar'),
              onTap: () => Navigator.pop(ctx, -1),
            ),
            const Divider(height: 1),
            for (final m in mechs)
              ListTile(
                leading: const Icon(Icons.engineering_outlined),
                title: Text(m.name),
                trailing: current == m.name ? const Icon(Icons.check) : null,
                onTap: () => Navigator.pop(ctx, m.id),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    await _run(() => _repo.assignMechanic(widget.orderId, picked == -1 ? null : picked));
  }

  Future<void> _addPhotos() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;

    List<XFile> files = [];
    try {
      if (source == ImageSource.camera) {
        final f = await _picker.pickImage(
            source: ImageSource.camera, imageQuality: 70, maxWidth: 1600);
        if (f != null) files = [f];
      } else {
        files =
            await _picker.pickMultiImage(imageQuality: 70, maxWidth: 1600);
      }
    } catch (e) {
      _snack('No se pudo acceder a las fotos: $e');
      return;
    }
    if (files.isEmpty) return;

    setState(() => _busy = true);
    try {
      await _repo.uploadPhotos(widget.orderId, files.map((f) => f.path).toList());
      await _reloadOrder();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(e.message);
      }
    }
  }

  Future<void> _deletePhoto(WoPhoto p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar foto'),
        content: const Text('¿Eliminar esta foto de la orden?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      await _repo.deletePhoto(widget.orderId, p.id);
      await _reloadOrder();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack(e.message);
      }
    }
  }

  void _viewPhoto(WoPhoto p) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        insetPadding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppBar(
              automaticallyImplyLeading: false,
              title: Text(p.fileName ?? 'Foto', maxLines: 1),
              actions: [
                IconButton(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.close)),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(p.url,
                    errorBuilder: (_, _, _) => const Padding(
                          padding: EdgeInsets.all(40),
                          child: Icon(Icons.broken_image_outlined, size: 48),
                        )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: Text(m)));

  Widget _photosSection(WorkOrder o) => Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('Fotos',
                      style: TextStyle(fontWeight: FontWeight.w700)),
                  if (!_closed)
                    TextButton.icon(
                      onPressed: _busy ? null : _addPhotos,
                      icon: const Icon(Icons.add_a_photo_outlined, size: 18),
                      label: const Text('Agregar'),
                    ),
                ],
              ),
              if (o.photos.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Sin fotos.',
                      style: TextStyle(color: Colors.black54)),
                )
              else
                SizedBox(
                  height: 92,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: o.photos.length,
                    separatorBuilder: (_, _) => const SizedBox(width: 8),
                    itemBuilder: (_, i) {
                      final p = o.photos[i];
                      return Stack(
                        children: [
                          GestureDetector(
                            onTap: () => _viewPhoto(p),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.network(
                                p.url,
                                width: 92,
                                height: 92,
                                fit: BoxFit.cover,
                                errorBuilder: (_, _, _) => Container(
                                  width: 92,
                                  height: 92,
                                  color: Colors.black12,
                                  child: const Icon(
                                      Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                          ),
                          if (!_closed)
                            Positioned(
                              top: -6,
                              right: -6,
                              child: IconButton(
                                iconSize: 18,
                                icon: const CircleAvatar(
                                  radius: 11,
                                  backgroundColor: Colors.black54,
                                  child: Icon(Icons.close,
                                      size: 13, color: Colors.white),
                                ),
                                onPressed:
                                    _busy ? null : () => _deletePhoto(p),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      );

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
              Row(
                children: [
                  Expanded(
                    child: Text(
                        'Mecánico: ${(o.mechanic != null && o.mechanic!.isNotEmpty) ? o.mechanic : 'Sin asignar'}'),
                  ),
                  if (!_closed)
                    TextButton.icon(
                      style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8)),
                      icon: const Icon(Icons.engineering_outlined, size: 18),
                      label: Text(
                          (o.mechanic != null && o.mechanic!.isNotEmpty)
                              ? 'Cambiar'
                              : 'Asignar'),
                      onPressed: _busy ? null : _assignMechanic,
                    ),
                ],
              ),
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
