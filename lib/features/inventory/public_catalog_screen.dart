import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:printing/printing.dart';
import 'package:qr/qr.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/app_toast.dart';
import '../../core/providers.dart';

/// Enlace del catálogo público de una sucursal.
class CatalogLink {
  final int id;
  final String name;
  final String? address;
  final String url;
  final String pdfUrl;

  CatalogLink({
    required this.id,
    required this.name,
    this.address,
    required this.url,
    required this.pdfUrl,
  });

  factory CatalogLink.fromJson(Map<String, dynamic> j) => CatalogLink(
    id: j['id'] as int,
    name: (j['name'] ?? '') as String,
    address: j['address'] as String?,
    url: (j['url'] ?? '') as String,
    pdfUrl: (j['pdf_url'] ?? '') as String,
  );

  /// Nombre para archivos: "Sucursal Centro" → "sucursal-centro".
  String get slug => name
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
}

final catalogLinksProvider = FutureProvider.autoDispose<List<CatalogLink>>((
  ref,
) async {
  final data = await ref.read(apiClientProvider).get('/catalog/branches');
  return ((data as Map<String, dynamic>)['data'] as List)
      .map((e) => CatalogLink.fromJson(e as Map<String, dynamic>))
      .toList();
});

/// Catálogo público por sucursal (como la web): QR, enlace para compartir,
/// PDF y QR descargable. Los clientes ven productos y precios (solo consulta).
class PublicCatalogScreen extends ConsumerWidget {
  const PublicCatalogScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(catalogLinksProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Catálogo público')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(catalogLinksProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text('$e', textAlign: TextAlign.center),
              ),
            ],
          ),
          data: (links) => ListView(
            padding: const EdgeInsets.all(12),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(4, 0, 4, 10),
                child: Text(
                  'Comparte el enlace o el QR de cada sucursal. Tus clientes '
                  'ven productos y precios (solo consulta) y en qué otra '
                  'sucursal hay disponibilidad.',
                  style: TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ),
              if (links.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Text(
                    'No tienes sucursales activas. Crea una sucursal para '
                    'publicar su catálogo.',
                    textAlign: TextAlign.center,
                  ),
                )
              else
                for (final l in links) _BranchCatalogCard(link: l),
            ],
          ),
        ),
      ),
    );
  }
}

class _BranchCatalogCard extends StatefulWidget {
  final CatalogLink link;
  const _BranchCatalogCard({required this.link});

  @override
  State<_BranchCatalogCard> createState() => _BranchCatalogCardState();
}

class _BranchCatalogCardState extends State<_BranchCatalogCard> {
  bool _pdfLoading = false;
  bool _qrLoading = false;

  CatalogLink get l => widget.link;

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: l.url));
    if (mounted) AppToast.success(context, 'Enlace copiado.');
  }

  Future<void> _shareLink() => SharePlus.instance.share(
    ShareParams(
      text: 'Mira nuestro catálogo (${l.name}): ${l.url}',
      subject: 'Catálogo ${l.name}',
    ),
  );

  Future<void> _open() async {
    final ok = await launchUrl(
      Uri.parse(l.url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) AppToast.error(context, 'No se pudo abrir el enlace.');
  }

  /// Descarga el PDF y abre el menú para guardarlo o enviarlo.
  Future<void> _pdf() async {
    setState(() => _pdfLoading = true);
    try {
      final res = await Dio().get<List<int>>(
        l.pdfUrl,
        options: Options(responseType: ResponseType.bytes),
      );
      await Printing.sharePdf(
        bytes: Uint8List.fromList(res.data ?? const []),
        filename: 'catalogo-${l.slug}.pdf',
      );
    } catch (_) {
      // Sin descarga directa: lo abre el navegador (que también lo baja).
      final ok = await launchUrl(
        Uri.parse(l.pdfUrl),
        mode: LaunchMode.externalApplication,
      );
      if (!ok && mounted) {
        AppToast.error(context, 'No se pudo descargar el PDF.');
      }
    } finally {
      if (mounted) setState(() => _pdfLoading = false);
    }
  }

  /// QR en PNG (con el nombre de la sucursal) para guardar o enviar.
  Future<void> _shareQr() async {
    setState(() => _qrLoading = true);
    try {
      final png = await buildCatalogQrPng(l.url, caption: l.name);
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              png,
              mimeType: 'image/png',
              name: 'qr-catalogo-${l.slug}.png',
            ),
          ],
          fileNameOverrides: ['qr-catalogo-${l.slug}.png'],
          text: 'Catálogo ${l.name}: ${l.url}',
        ),
      );
    } finally {
      if (mounted) setState(() => _qrLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final small = ButtonStyle(
      minimumSize: const WidgetStatePropertyAll(Size(0, 40)),
      padding: const WidgetStatePropertyAll(
        EdgeInsets.symmetric(horizontal: 12),
      ),
      visualDensity: VisualDensity.compact,
    );
    Widget spinner() => const SizedBox(
      width: 16,
      height: 16,
      child: CircularProgressIndicator(strokeWidth: 2),
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.storefront, size: 20, color: scheme.primary),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    l.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 12),
              child: Text(
                (l.address ?? '').trim().isEmpty
                    ? 'Catálogo de esta sucursal'
                    : l.address!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Colors.black54),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.black12),
              ),
              child: QrView(data: l.url, size: 168),
            ),
            const SizedBox(height: 12),
            // Enlace: tocar para copiar.
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: _copy,
              child: Container(
                padding: const EdgeInsets.fromLTRB(10, 8, 6, 8),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest.withValues(alpha: .5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        l.url,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.copy, size: 18, color: Colors.black54),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              icon: const Icon(Icons.share, size: 18),
              label: const Text('Compartir enlace'),
              onPressed: _shareLink,
            ),
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  style: small,
                  icon: const Icon(Icons.open_in_new, size: 18),
                  label: const Text('Ver'),
                  onPressed: _open,
                ),
                OutlinedButton.icon(
                  style: small.copyWith(
                    foregroundColor: WidgetStatePropertyAll(
                      Colors.red.shade700,
                    ),
                  ),
                  icon: _pdfLoading
                      ? spinner()
                      : const Icon(Icons.picture_as_pdf_outlined, size: 18),
                  label: const Text('PDF'),
                  onPressed: _pdfLoading ? null : _pdf,
                ),
                OutlinedButton.icon(
                  style: small,
                  icon: _qrLoading
                      ? spinner()
                      : const Icon(Icons.qr_code_2, size: 18),
                  label: const Text('Descargar QR'),
                  onPressed: _qrLoading ? null : _shareQr,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Matriz del QR (corrección M, como la web).
QrImage _qrImage(String data) => QrImage(
  QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.M),
);

/// Dibuja un QR en pantalla (sin paquetes extra: usa `qr`, ya presente).
class QrView extends StatelessWidget {
  final String data;
  final double size;
  const QrView({super.key, required this.data, this.size = 160});

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _QrPainter(_qrImage(data))),
  );
}

class _QrPainter extends CustomPainter {
  final QrImage qr;
  _QrPainter(this.qr);

  @override
  void paint(Canvas canvas, Size size) =>
      _paintQr(canvas, qr, Offset.zero, size.width);

  @override
  bool shouldRepaint(covariant _QrPainter old) => old.qr != qr;
}

void _paintQr(Canvas canvas, QrImage qr, Offset origin, double side) {
  final n = qr.moduleCount;
  final cell = side / n;
  final paint = Paint()
    ..color = Colors.black
    ..isAntiAlias = false;
  for (var r = 0; r < n; r++) {
    for (var c = 0; c < n; c++) {
      if (qr.isDark(r, c)) {
        // +0.5 evita líneas blancas finas entre módulos.
        canvas.drawRect(
          Rect.fromLTWH(
            origin.dx + c * cell,
            origin.dy + r * cell,
            cell + .5,
            cell + .5,
          ),
          paint,
        );
      }
    }
  }
}

/// PNG del QR (fondo blanco, margen y el nombre debajo) para compartir.
Future<Uint8List> buildCatalogQrPng(String data, {String? caption}) async {
  const side = 600.0, margin = 48.0;
  final hasCaption = caption != null && caption.trim().isNotEmpty;
  final height = side + margin * 2 + (hasCaption ? 70 : 0);
  final width = side + margin * 2;

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width, height),
    Paint()..color = Colors.white,
  );
  _paintQr(canvas, _qrImage(data), const Offset(margin, margin), side);

  if (hasCaption) {
    final tp = TextPainter(
      text: TextSpan(
        text: caption.trim(),
        style: const TextStyle(
          color: Colors.black,
          fontSize: 34,
          fontWeight: FontWeight.w700,
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: width - margin * 2);
    tp.paint(canvas, Offset((width - tp.width) / 2, margin + side + 18));
  }

  final image = await recorder.endRecording().toImage(
    width.toInt(),
    height.toInt(),
  );
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
}
