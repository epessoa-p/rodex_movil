import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/app_toast.dart';
import '../../core/company_logo.dart';
import '../../core/format.dart';
import '../../core/models.dart';
import '../../core/providers.dart';
import '../../core/upper_case.dart';
import '../../core/whatsapp.dart';
import '../../core/module_colors.dart';
import '../agenda/agenda_repository.dart';
import '../products/products_screen.dart';
import 'work_order_letter_pdf.dart';
import 'service_pick_sheet.dart';
import 'work_order_edit_sheet.dart';
import 'work_order_pdf.dart';
import 'workshop_repository.dart';

class WorkOrderDetailScreen extends ConsumerStatefulWidget {
  final int orderId;
  const WorkOrderDetailScreen({super.key, required this.orderId});

  @override
  ConsumerState<WorkOrderDetailScreen> createState() =>
      _WorkOrderDetailScreenState();
}

class _WorkOrderDetailScreenState extends ConsumerState<WorkOrderDetailScreen> {
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
      if (mounted) {
        setState(() {
          _order = o;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _loading = false;
        });
      }
    }
  }

  Future<void> _run(Future<WorkOrder> Function() action) async {
    setState(() => _busy = true);
    try {
      final o = await action();
      if (mounted) {
        setState(() {
          _order = o;
          _busy = false;
        });
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        AppToast.apiError(context, e);
      }
    }
  }

  bool get _closed =>
      _order?.status == 'entregada' || _order?.status == 'anulada';

  Future<void> _addService() async {
    // Catálogo de servicios (con precio) para elegir en vez de escribir uno
    // nuevo: el backend solo reutiliza si el nombre coincide exacto, así que
    // teclearlo distinto creaba duplicados en el catálogo.
    List<ServiceOption> catalog = const [];
    try {
      catalog = (await ref.read(appointmentMetaProvider.future)).services;
    } catch (_) {
      // sin catálogo: texto libre igual funciona
    }
    if (!mounted) return;

    final picked = await showModalBottomSheet<ServicePick>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => AddServiceSheet(catalog: catalog),
    );
    if (picked == null || !mounted) return;
    await _run(
      () => _repo.addService(
        widget.orderId,
        description: picked.name,
        price: picked.price,
        quantity: picked.quantity,
      ),
    );
    // Si el servicio era nuevo, el backend lo creó en el catálogo: refrescar
    // la lista para que aparezca en la próxima búsqueda (esta u otra OT).
    if (!catalog.any(
      (s) => s.name.toLowerCase() == picked.name.toLowerCase(),
    )) {
      ref.invalidate(appointmentMetaProvider);
    }
  }

  /// Edita los datos de la OT (solo en curso).
  Future<void> _editOrder() async {
    final o = _order;
    if (o == null) return;
    final updated = await showModalBottomSheet<WorkOrder>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => WorkOrderEditSheet(order: o),
    );
    if (updated != null && mounted) {
      setState(() => _order = updated);
      AppToast.success(context, 'Datos actualizados.');
    }
  }

  /// Reabre una OT entregada para corregirla (anula el cobro y devuelve el
  /// stock). El backend solo lo permite con la caja del cobro abierta.
  Future<void> _reopenOrder() async {
    final o = _order;
    if (o == null) return;
    if (!o.canReopen) {
      AppToast.error(
        context,
        o.reopenBlockedReason ?? 'Esta orden ya no se puede corregir.',
        title: 'No se puede reabrir',
      );
      return;
    }
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reabrir para corregir'),
        content: Text(
          'Se anulará el cobro de ${o.code} (sale de la caja) y los repuestos '
          'volverán al stock.\n\nDespués podrás corregirla y cobrarla de nuevo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reabrir'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(() => _repo.reopenOrder(o.id));
    if (mounted && _order?.status != 'entregada') {
      AppToast.success(
        context,
        'Cobro anulado y stock devuelto: ya puedes corregirla.',
        title: 'OT reabierta',
      );
    }
  }

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

    final qty = TextEditingController(text: '1');
    final price = TextEditingController(
      text: product!.price.toStringAsFixed(2),
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(product!.name),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: qty,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Cantidad'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: price,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Precio unitario',
                prefixText: 'Bs ',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Agregar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => _repo.addPart(
        widget.orderId,
        productId: product!.id,
        quantity: int.tryParse(qty.text) ?? 1,
        unitPrice: double.tryParse(price.text) ?? product!.price,
      ),
    );
  }

  Future<void> _deliver() async {
    final to = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Entregar y cobrar'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Total a cobrar: ${money(_order!.total)}'),
            const SizedBox(height: 8),
            TextField(
              textCapitalization: TextCapitalization.characters,
              inputFormatters: upperCaseFormatters,
              controller: to,
              decoration: const InputDecoration(
                labelText: 'Entregado a (opcional)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cobrar y entregar'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(
      () => _repo.deliver(
        widget.orderId,
        deliveredTo: to.text.trim().isEmpty ? null : to.text.trim(),
      ),
    );
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
          if (!_closed)
            IconButton(
              tooltip: 'Editar datos',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _busy ? null : _editOrder,
            ),
          if (o.status == 'entregada')
            IconButton(
              tooltip: o.canReopen
                  ? 'Reabrir para corregir'
                  : (o.reopenBlockedReason ?? 'No se puede reabrir'),
              icon: const Icon(Icons.lock_reset),
              onPressed: _busy ? null : _reopenOrder,
            ),
          PopupMenuButton<String>(
            tooltip: 'Compartir',
            icon: const Icon(Icons.share_outlined),
            enabled: !_busy,
            onSelected: (v) => switch (v) {
              'receipt_wa' => _shareReceiptPickFormat(toClient: true),
              'tracking_wa' => _shareTracking(toClient: true),
              'receipt' => _shareReceiptPickFormat(),
              _ => _shareTracking(),
            },
            itemBuilder: (_) {
              // Directo al WhatsApp del cliente (si tiene teléfono) o al
              // selector de apps del sistema.
              final hasPhone = WhatsApp.number(o.clientPhone) != null;
              final phoneHint = hasPhone
                  ? (o.clientPhone ?? '')
                  : 'El cliente no tiene teléfono';
              return [
                PopupMenuItem(
                  value: 'receipt_wa',
                  enabled: hasPhone,
                  child: ListTile(
                    enabled: hasPhone,
                    leading: const Icon(Icons.picture_as_pdf_outlined),
                    title: const Text('Recibo (PDF) al WhatsApp del cliente'),
                    subtitle: Text(phoneHint),
                  ),
                ),
                PopupMenuItem(
                  value: 'tracking_wa',
                  enabled: hasPhone,
                  child: ListTile(
                    enabled: hasPhone,
                    leading: const Icon(Icons.link),
                    title: const Text('Seguimiento al WhatsApp del cliente'),
                    subtitle: Text(phoneHint),
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem(
                  value: 'receipt',
                  child: ListTile(
                    leading: Icon(Icons.share_outlined),
                    title: Text('Compartir recibo (PDF) con otra app'),
                  ),
                ),
                const PopupMenuItem(
                  value: 'tracking',
                  child: ListTile(
                    leading: Icon(Icons.share_outlined),
                    title: Text('Compartir seguimiento con otra app'),
                  ),
                ),
              ];
            },
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

              // Servicios y repuestos: botón "Agregar" en la cabecera de la
              // tarjeta (como en Nueva cita) y × por línea para quitar.
              _section(
                'Servicios',
                icon: Icons.handyman_outlined,
                color: _Accent.services,
                action: _closed
                    ? null
                    : _HeaderAction(
                        label: o.services.isEmpty
                            ? 'Agregar servicio'
                            : 'Agregar',
                        onPressed: _busy ? null : _addService,
                      ),
                o.services.isEmpty
                    ? [
                        const ListTile(
                          dense: true,
                          title: Text(
                            'Sin servicios',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      ]
                    : [
                        for (final s in o.services)
                          ListTile(
                            dense: true,
                            title: Text(s.description),
                            subtitle: Text(
                              '${s.quantity} x ${money(s.price)}${s.mechanic != null ? ' · ${s.mechanic}' : ''}',
                            ),
                            trailing: _lineTrailing(
                              money(s.subtotal),
                              onRemove: () => _removeLine(
                                '¿Quitar el servicio «${s.description}»?',
                                () => _repo.removeService(widget.orderId, s.id),
                              ),
                            ),
                          ),
                      ],
              ),

              const SizedBox(height: 8),
              _section(
                'Repuestos',
                icon: Icons.inventory_2_outlined,
                color: _Accent.parts,
                action: _closed
                    ? null
                    : _HeaderAction(
                        label: o.parts.isEmpty ? 'Agregar repuesto' : 'Agregar',
                        onPressed: _busy ? null : _addPart,
                      ),
                o.parts.isEmpty
                    ? [
                        const ListTile(
                          dense: true,
                          title: Text(
                            'Sin repuestos',
                            style: TextStyle(color: Colors.black54),
                          ),
                        ),
                      ]
                    : [
                        for (final p in o.parts)
                          ListTile(
                            dense: true,
                            title: Text(p.name),
                            subtitle: Text(
                              '${p.quantity} x ${money(p.unitPrice)}',
                            ),
                            trailing: _lineTrailing(
                              money(p.subtotal),
                              onRemove: () => _removeLine(
                                '¿Quitar el repuesto «${p.name}»?',
                                () => _repo.removePart(widget.orderId, p.id),
                              ),
                            ),
                          ),
                      ],
              ),

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

  /// Con [toClient] abre directamente el chat de WhatsApp del cliente con el
  /// enlace ya escrito; si no, el selector de apps del sistema.
  Future<void> _shareTracking({bool toClient = false}) async {
    final o = _order;
    if (o == null) return;
    setState(() => _busy = true);
    try {
      final url = await _repo.shareLink(o.id);
      if (!mounted) return;
      setState(() => _busy = false);
      final veh = o.vehicle != null ? ' (${o.vehicle})' : '';
      if (toClient) {
        final text =
            '${_greeting(o)}Puede seguir el estado de su orden ${o.code}$veh aquí:\n$url';
        if (!await WhatsApp.openChat(o.clientPhone, text)) {
          _snack('No se pudo abrir WhatsApp.');
        }
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          text: 'Sigue el estado de tu orden ${o.code}$veh aquí:\n$url',
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        AppToast.apiError(context, e);
      }
    }
  }

  /// Pregunta el formato (ticket 80 mm o tamaño carta) y comparte el recibo.
  Future<void> _shareReceiptPickFormat({bool toClient = false}) async {
    final letter = await showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Text(
                'Formato del recibo',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.receipt_long_outlined),
              title: const Text('Ticket (80 mm)'),
              subtitle: const Text('Compacto, como el de la impresora'),
              onTap: () => Navigator.pop(ctx, false),
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Tamaño carta'),
              subtitle: const Text(
                'Con logo, tablas, firmas; para imprimir o enviar',
              ),
              onTap: () => Navigator.pop(ctx, true),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (letter == null || !mounted) return;
    await _shareReceipt(toClient: toClient, letter: letter);
  }

  /// Con [toClient] abre WhatsApp en el chat del cliente con el PDF adjunto
  /// (Android); si no se puede (sin WhatsApp), cae al compartir genérico.
  /// [letter]: tamaño carta; si no, ticket 80 mm.
  Future<void> _shareReceipt({
    bool toClient = false,
    bool letter = false,
  }) async {
    final o = _order;
    if (o == null) return;
    setState(() => _busy = true);
    try {
      final me = ref.read(authControllerProvider).me;
      final logo = await loadCompanyLogo(me?.company?.logoUrl);
      final bytes = letter
          ? await buildWorkOrderLetterPdf(o, company: me?.company, logo: logo)
          : await buildWorkOrderPdf(o, company: me?.company?.name, logo: logo);
      final filename = '${o.code}${letter ? '-carta' : ''}.pdf';
      if (!mounted) return;
      setState(() => _busy = false);
      if (toClient) {
        final sent = await WhatsApp.sendFile(
          bytes,
          filename,
          o.clientPhone,
          text: '${_greeting(o)}Le enviamos el recibo de su orden ${o.code}.',
        );
        if (sent) return;
        if (mounted) {
          AppToast.info(
            context,
            'WhatsApp no disponible: elige la app para compartir.',
          );
        }
      }
      await Printing.sharePdf(bytes: bytes, filename: filename);
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        _snack('No se pudo generar el PDF: $e');
      }
    }
  }

  Future<void> _reloadOrder() async {
    final o = await _repo.order(widget.orderId);
    if (mounted) {
      setState(() {
        _order = o;
        _busy = false;
      });
    }
  }

  Future<void> _assignMechanic() async {
    List<Mechanic> mechs;
    try {
      mechs = await _repo.mechanics();
    } on ApiException catch (e) {
      if (mounted) AppToast.apiError(context, e);
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
    await _run(
      () => _repo.assignMechanic(widget.orderId, picked == -1 ? null : picked),
    );
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
          source: ImageSource.camera,
          imageQuality: 70,
          maxWidth: 1600,
        );
        if (f != null) files = [f];
      } else {
        files = await _picker.pickMultiImage(imageQuality: 70, maxWidth: 1600);
      }
    } catch (e) {
      _snack('No se pudo acceder a las fotos: $e');
      return;
    }
    if (files.isEmpty) return;

    setState(() => _busy = true);
    try {
      await _repo.uploadPhotos(
        widget.orderId,
        files.map((f) => f.path).toList(),
      );
      await _reloadOrder();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        AppToast.apiError(context, e);
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
            child: const Text('Cancelar'),
          ),
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
        AppToast.apiError(context, e);
      }
    }
  }

  void _viewPhoto(WoPhoto p) {
    final hasCaption = p.caption != null && p.caption!.trim().isNotEmpty;
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
                if (!_closed)
                  IconButton(
                    tooltip: 'Comentario',
                    onPressed: () {
                      Navigator.pop(ctx);
                      _editCaption(p);
                    },
                    icon: const Icon(Icons.comment_outlined),
                  ),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            Flexible(
              child: InteractiveViewer(
                child: Image.network(
                  p.url,
                  errorBuilder: (_, _, _) => const Padding(
                    padding: EdgeInsets.all(40),
                    child: Icon(Icons.broken_image_outlined, size: 48),
                  ),
                ),
              ),
            ),
            if (hasCaption)
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text(p.caption!),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _editCaption(WoPhoto p) async {
    final ctrl = TextEditingController(text: p.caption ?? '');
    final saved = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Comentario de la foto'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          maxLength: 500,
          decoration: const InputDecoration(
            hintText: 'Ej: Cambiar esta pieza gastada por una nueva',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (saved == null) return;
    setState(() => _busy = true);
    try {
      await _repo.updatePhotoCaption(
        widget.orderId,
        p.id,
        saved.isEmpty ? null : saved,
      );
      await _reloadOrder();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        AppToast.apiError(context, e);
      }
    }
  }

  /// "Hola NOMBRE, le escribimos de EMPRESA. " para los mensajes al cliente.
  String _greeting(WorkOrder o) {
    final company = ref.read(authControllerProvider).me?.company?.name ?? '';
    final name = (o.client ?? '').trim();
    return 'Hola${name.isNotEmpty ? ' $name' : ''}, le escribimos'
        '${company.isNotEmpty ? ' de $company' : ''}. ';
  }

  Future<void> _whatsapp(WorkOrder o) async {
    if (WhatsApp.number(o.clientPhone) == null) {
      _snack('Este cliente no tiene teléfono registrado.');
      return;
    }
    final veh = o.vehicle != null ? ' (${o.vehicle})' : '';
    final msg = '${_greeting(o)}Sobre su orden de trabajo ${o.code}$veh.';
    if (!await WhatsApp.openChat(o.clientPhone, msg)) {
      _snack('No se pudo abrir WhatsApp.');
    }
  }

  Future<void> _call(WorkOrder o) async {
    final phone = o.clientPhone;
    if (phone == null || phone.trim().isEmpty) {
      _snack('Este cliente no tiene teléfono registrado.');
      return;
    }
    final url = Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}');
    if (!await launchUrl(url)) {
      _snack('No se pudo iniciar la llamada.');
    }
  }

  // Validaciones y errores locales: toast rojo arriba (visible sobre hojas).
  void _snack(String m) => AppToast.error(context, m);

  Widget _photosSection(WorkOrder o) => _AccentCard(
    color: _Accent.photos,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(
                    Icons.photo_library_outlined,
                    size: 18,
                    color: _Accent.photos,
                  ),
                  SizedBox(width: 6),
                  Text('Fotos', style: TextStyle(fontWeight: FontWeight.w700)),
                ],
              ),
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
              child: Text(
                'Sin fotos.',
                style: TextStyle(color: Colors.black54),
              ),
            )
          else
            SizedBox(
              height: 132,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: o.photos.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) {
                  final p = o.photos[i];
                  final hasCaption =
                      p.caption != null && p.caption!.trim().isNotEmpty;
                  return SizedBox(
                    width: 96,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            GestureDetector(
                              onTap: () => _viewPhoto(p),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(10),
                                child: Image.network(
                                  p.url,
                                  width: 96,
                                  height: 96,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, _, _) => Container(
                                    width: 96,
                                    height: 96,
                                    color: Colors.black12,
                                    child: const Icon(
                                      Icons.broken_image_outlined,
                                    ),
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
                                    child: Icon(
                                      Icons.close,
                                      size: 13,
                                      color: Colors.white,
                                    ),
                                  ),
                                  onPressed: _busy
                                      ? null
                                      : () => _deletePhoto(p),
                                ),
                              ),
                            if (hasCaption)
                              const Positioned(
                                left: 4,
                                bottom: 4,
                                child: CircleAvatar(
                                  radius: 9,
                                  backgroundColor: Colors.black54,
                                  child: Icon(
                                    Icons.comment,
                                    size: 10,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(height: 3),
                        Expanded(
                          child: InkWell(
                            onTap: _closed ? null : () => _editCaption(p),
                            child: Text(
                              hasCaption
                                  ? p.caption!
                                  : (_closed ? '' : 'Comentar…'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: hasCaption
                                    ? Colors.black87
                                    : Colors.blue,
                                fontStyle: hasCaption
                                    ? FontStyle.normal
                                    : FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    ),
  );

  Widget _header(WorkOrder o) => _AccentCard(
    color: _Accent.status(o.status),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            o.statusLabel,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Expanded(child: Text('Cliente: ${o.client ?? '-'}')),
              IconButton(
                tooltip: 'WhatsApp',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.chat, color: Color(0xFF25D366)),
                onPressed: () => _whatsapp(o),
              ),
              IconButton(
                tooltip: 'Llamar',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.call_outlined),
                onPressed: () => _call(o),
              ),
            ],
          ),
          Text('Vehículo: ${o.vehicle ?? '-'}'),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Mecánico: ${(o.mechanic != null && o.mechanic!.isNotEmpty) ? o.mechanic : 'Sin asignar'}',
                ),
              ),
              if (!_closed)
                TextButton.icon(
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                  ),
                  icon: const Icon(Icons.engineering_outlined, size: 18),
                  label: Text(
                    (o.mechanic != null && o.mechanic!.isNotEmpty)
                        ? 'Cambiar'
                        : 'Asignar',
                  ),
                  onPressed: _busy ? null : _assignMechanic,
                ),
            ],
          ),
          _recepLine('Kilometraje', o.mileage != null ? '${o.mileage}' : null),
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
      child: Text(
        '$label: $value',
        style: const TextStyle(color: Colors.black54),
      ),
    );
  }

  Widget _diagnosisSection(WorkOrder o) {
    final has = o.diagnosis != null && o.diagnosis!.trim().isNotEmpty;
    return _section(
      'Diagnóstico',
      icon: Icons.medical_information_outlined,
      color: _Accent.diagnosis,
      [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                has ? o.diagnosis! : 'Sin diagnóstico registrado.',
                style: TextStyle(color: has ? null : Colors.black54),
              ),
              if (!_closed) ...[
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: _busy ? null : () => _editDiagnosis(o),
                  icon: const Icon(Icons.edit_note),
                  label: Text(
                    has ? 'Editar diagnóstico' : 'Agregar diagnóstico',
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
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
            hintText: 'Diagnóstico técnico…',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    final text = ctrl.text.trim();
    if (text.isEmpty) {
      AppToast.error(context, 'Escribe el diagnóstico.');
      return;
    }
    await _run(() => _repo.saveDiagnosis(o.id, text));
  }

  /// Tarjeta de sección. [action] va arriba a la derecha (como la tarjeta de
  /// Servicios en Nueva cita).
  Widget _section(
    String title,
    List<Widget> children, {
    IconData? icon,
    _HeaderAction? action,
    Color color = Colors.blueGrey,
  }) => _AccentCard(
    color: color,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, action != null ? 4 : 12, 8, 4),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              // Compacto y flexible: a 360 dp "Agregar servicio" desbordaba
              // la fila (overflow por frame = ANR en debug).
              if (action != null)
                Flexible(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: action.onPressed,
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                )
              else
                const SizedBox(width: 8),
            ],
          ),
        ),
        ...children,
        const SizedBox(height: 6),
      ],
    ),
  );

  /// Subtotal de la línea + × para quitarla (solo con la OT abierta).
  Widget _lineTrailing(String amount, {required VoidCallback onRemove}) {
    if (_closed) return Text(amount);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(amount),
        IconButton(
          visualDensity: VisualDensity.compact,
          tooltip: 'Quitar',
          icon: const Icon(Icons.close, size: 18, color: Colors.black45),
          onPressed: _busy ? null : onRemove,
        ),
      ],
    );
  }

  /// Confirma y quita una línea (servicio o repuesto) de la OT.
  Future<void> _removeLine(
    String question,
    Future<WorkOrder> Function() action,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitar de la OT'),
        content: Text(question),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    await _run(action);
  }

  Widget _totals(WorkOrder o) => _AccentCard(
    color: _Accent.totals,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          _row('Servicios', o.subtotalServices),
          _row('Repuestos', o.subtotalParts),
          if (o.discount > 0) _row('Descuento', -o.discount),
          const Divider(),
          _row('Total', o.total, bold: true),
          if (o.paidAmount > 0) _row('Pagado', o.paidAmount),
          if (o.balance > 0) _row('Saldo', o.balance),
        ],
      ),
    ),
  );

  Widget _row(String k, double v, {bool bold = false}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          k,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
          ),
        ),
        Text(
          money(v),
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.normal,
          ),
        ),
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
              minimumSize: const Size.fromHeight(48),
            ),
            icon: const Icon(Icons.arrow_forward),
            label: Text(label),
            onPressed: _busy
                ? null
                : () => _run(() => _repo.changeStatus(o.id, next)),
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
            child: Text(
              'Agrega servicios o repuestos para poder cobrar.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
          ),
      ],
    );
  }
}

/// Acción de cabecera de una tarjeta de sección ("+ Agregar …").
class _HeaderAction {
  final String label;
  final VoidCallback? onPressed;
  const _HeaderAction({required this.label, this.onPressed});
}

/// Resultado de la hoja "Agregar servicio".

/// Colores de acento de los recuadros del detalle de OT: cada sección tiene el
/// suyo (franja izquierda + ícono) para identificarla de un vistazo al
/// deslizar, aunque esté vacía. Coherentes con el resto de la app.
abstract final class _Accent {
  static const photos = Colors.indigo;
  static const diagnosis = Colors.blue;
  static const services = ModuleColors.workOrders; // el de Taller
  static const parts = ModuleColors.purchases; // el de repuestos/compras
  static const totals = Colors.green;

  /// Cabecera: el color del estado de la OT (mismos que el listado).
  static Color status(String status) => switch (status) {
    'recibida' => Colors.blueGrey,
    'diagnosticada' => Colors.indigo,
    'en_proceso' => Colors.orange,
    'terminada' => Colors.green,
    'entregada' => Colors.teal,
    'anulada' => Colors.red,
    _ => Colors.grey,
  };
}

/// `Card` del tema con una franja de color de 4 px en el borde izquierdo.
class _AccentCard extends StatelessWidget {
  final Color color;
  final Widget child;
  const _AccentCard({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: color, width: 4)),
        ),
        child: child,
      ),
    );
  }
}
