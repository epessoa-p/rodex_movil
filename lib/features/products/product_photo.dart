import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/app_toast.dart';
import '../../core/image_disk_cache.dart';
import '../../core/models.dart';
import '../pos/pos_repository.dart';

/// De dónde salen los bytes de una miniatura. En producción es la caché en
/// disco; los tests lo sustituyen para no tocar la red.
final thumbLoaderProvider = Provider<ThumbLoader>((ref) => loadThumb);

/// Miniatura de la foto del producto. Si no hay foto muestra un marcador; con
/// [showBadge] agrega el distintivo de cámara para invitar a tocarla.
///
/// Los bytes pasan por la caché en disco ([loadThumb]): la segunda vez que se
/// abre el listado no se descarga nada.
class ProductThumb extends ConsumerStatefulWidget {
  final String? imageUrl;
  final double size;
  final bool showBadge;
  final bool busy;

  /// Si el producto tiene foto. Se pasa aparte de [imageUrl] porque con las
  /// fotos ocultas no hay imagen que pintar pero igual hay que distinguir
  /// cuáles ya tienen y cuáles faltan.
  final bool? hasPhoto;

  const ProductThumb({
    super.key,
    this.imageUrl,
    this.size = 44,
    this.showBadge = false,
    this.busy = false,
    this.hasPhoto,
  });

  @override
  ConsumerState<ProductThumb> createState() => _ProductThumbState();
}

class _ProductThumbState extends ConsumerState<ProductThumb> {
  Uint8List? _bytes;
  String? _loadedUrl;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ProductThumb old) {
    super.didUpdateWidget(old);
    if (old.imageUrl != widget.imageUrl) _load();
  }

  Future<void> _load() async {
    final url = widget.imageUrl;
    if (url == null || url.isEmpty) {
      if (_bytes != null) setState(() => _bytes = null);
      return;
    }
    if (url == _loadedUrl && _bytes != null) return;
    _loadedUrl = url;
    final bytes = await ref.read(thumbLoaderProvider)(url);
    // Otra foto llegó primero (la fila se recicló al hacer scroll).
    if (!mounted || _loadedUrl != url) return;
    setState(() => _bytes = bytes);
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final showBadge = widget.showBadge;
    final busy = widget.busy;
    final bytes = _bytes;
    final radius = size / 4;
    final badge = size / 2.6;
    final has = widget.hasPhoto ?? (widget.imageUrl != null);
    // Rojo = sin foto (se ve de un vistazo cuáles faltan, también con las
    // fotos ocultas); verde = ya tiene.
    final mark = has ? Theme.of(context).colorScheme.primary : Colors.red;

    Widget placeholder() => Icon(
      // Con foto pero oculta: ícono de imagen. Sin foto: caja vacía.
      has ? Icons.image_outlined : Icons.inventory_2_outlined,
      size: size / 2,
      color: has ? Colors.black38 : Colors.red.withValues(alpha: 0.35),
    );

    return SizedBox(
      width: size + (showBadge ? 4 : 0),
      height: size + (showBadge ? 4 : 0),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: has
                  ? Colors.black.withValues(alpha: 0.06)
                  : Colors.red.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: has ? Colors.black12 : Colors.red.withValues(alpha: 0.5),
                width: has ? 1 : 1.5,
              ),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: bytes == null
                // Sin foto todavía (o no se pudo traer): marcador, sin
                // indicador animado que distraiga en cada fila.
                ? placeholder()
                : Image.memory(
                    bytes,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    gaplessPlayback: true,
                    // La miniatura se decodifica pequeña: no carga la foto
                    // completa en memoria por cada fila del listado.
                    cacheWidth: (size * MediaQuery.devicePixelRatioOf(context))
                        .round(),
                    filterQuality: FilterQuality.low,
                    errorBuilder: (_, _, _) => placeholder(),
                  ),
          ),
          if (busy)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.black38,
                  borderRadius: BorderRadius.circular(radius),
                ),
                alignment: Alignment.center,
                child: SizedBox(
                  width: size / 2.5,
                  height: size / 2.5,
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          if (showBadge && !busy)
            Positioned(
              right: 0,
              bottom: 0,
              child: Container(
                width: badge,
                height: badge,
                decoration: BoxDecoration(
                  color: mark,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Icon(
                  // Verde con cámara = tiene foto; rojo con "+" = falta.
                  has ? Icons.photo_camera : Icons.add_a_photo,
                  size: badge * 0.55,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

enum _PhotoAction { camera, gallery, remove }

/// Hoja de "cambiar foto" (cámara, galería y quitar) + subida inmediata.
/// Devuelve la ficha ya actualizada, o null si se canceló o falló.
Future<ProductDetail?> pickAndUpdateProductPhoto(
  BuildContext context,
  WidgetRef ref, {
  required int productId,
  required String productName,
  required bool hasPhoto,
  // Se avisa al empezar la subida (la hoja ya se cerró) para que la pantalla
  // muestre el indicador solo mientras dura, no mientras se elige.
  VoidCallback? onUploadStart,
}) async {
  final action = await showModalBottomSheet<_PhotoAction>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            dense: true,
            title: Text(
              productName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
            subtitle: Text(hasPhoto ? 'Cambiar foto' : 'Agregar foto'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.photo_camera_outlined),
            title: const Text('Tomar foto'),
            onTap: () => Navigator.pop(ctx, _PhotoAction.camera),
          ),
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Elegir de la galería'),
            onTap: () => Navigator.pop(ctx, _PhotoAction.gallery),
          ),
          if (hasPhoto)
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.red),
              title: const Text(
                'Quitar foto',
                style: TextStyle(color: Colors.red),
              ),
              onTap: () => Navigator.pop(ctx, _PhotoAction.remove),
            ),
        ],
      ),
    ),
  );
  if (action == null || !context.mounted) return null;

  final repo = ref.read(posRepositoryProvider);
  try {
    if (action == _PhotoAction.remove) {
      onUploadStart?.call();
    }
    if (action == _PhotoAction.remove) {
      final updated = await repo.removeProductPhoto(productId);
      if (context.mounted) AppToast.success(context, 'Foto quitada.');
      return updated;
    }

    final picked = await ImagePicker().pickImage(
      source: action == _PhotoAction.camera
          ? ImageSource.camera
          : ImageSource.gallery,
      maxWidth: 1280,
      imageQuality: 80,
    );
    if (picked == null) return null;
    onUploadStart?.call();

    final updated = await repo.updateProductPhoto(productId, picked.path);
    if (context.mounted) AppToast.success(context, 'Foto actualizada.');
    return updated;
  } on ApiException catch (e) {
    if (context.mounted) AppToast.apiError(context, e);
    return null;
  } catch (_) {
    if (context.mounted) {
      AppToast.error(context, 'No se pudo obtener la imagen.');
    }
    return null;
  }
}
