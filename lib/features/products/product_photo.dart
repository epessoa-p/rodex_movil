import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/app_toast.dart';
import '../../core/models.dart';
import '../pos/pos_repository.dart';

/// Miniatura de la foto del producto. Si no hay foto muestra un marcador; con
/// [showBadge] agrega el distintivo de cámara para invitar a tocarla.
class ProductThumb extends StatelessWidget {
  final String? imageUrl;
  final double size;
  final bool showBadge;
  final bool busy;

  const ProductThumb({
    super.key,
    this.imageUrl,
    this.size = 44,
    this.showBadge = false,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final url = imageUrl;
    final radius = size / 4;
    final badge = size / 2.6;

    Widget placeholder() =>
        Icon(Icons.inventory_2_outlined, size: size / 2, color: Colors.black26);

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
              color: Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(color: Colors.black12),
            ),
            clipBehavior: Clip.antiAlias,
            alignment: Alignment.center,
            child: url == null
                ? placeholder()
                : Image.network(
                    url,
                    fit: BoxFit.cover,
                    width: size,
                    height: size,
                    // La miniatura se decodifica pequeña: no carga la foto
                    // completa en memoria por cada fila del listado.
                    cacheWidth: (size * 3).round(),
                    errorBuilder: (_, _, _) => placeholder(),
                    // Sin indicador animado: el marcador se ve hasta que
                    // llega el primer cuadro de la imagen.
                    frameBuilder: (_, child, frame, wasSync) =>
                        frame == null && !wasSync ? placeholder() : child,
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
                  color: Theme.of(context).colorScheme.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
                child: Icon(
                  Icons.photo_camera,
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
