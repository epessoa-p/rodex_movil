import 'dart:io';
import 'dart:ui' as ui;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Logo de la empresa para incrustar en los PDF (recibos, comprobantes).
///
/// Se descarga UNA vez, se reduce a [_targetWidth] px (PNG) y se guarda en
/// disco, así el PDF pesa poco y funciona sin red después de la primera vez.
/// Cualquier fallo devuelve null: el PDF sale sin logo, nunca falla por esto.
const _targetWidth = 300;
final Map<String, Uint8List> _memory = {};

Future<Uint8List?> loadCompanyLogo(String? url) async {
  if (url == null || url.trim().isEmpty) return null;
  final cached = _memory[url];
  if (cached != null) return cached;

  try {
    final file = await _cacheFile(url);
    if (file != null && await file.exists()) {
      final bytes = await file.readAsBytes();
      if (_isPng(bytes)) {
        _memory[url] = bytes;
        return bytes;
      }
      // Archivo corrupto/incompleto: se vuelve a generar.
      await file.delete();
    }

    final res = await Dio().get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 8),
        sendTimeout: const Duration(seconds: 8),
      ),
    );
    final raw = res.data;
    if (raw == null || raw.isEmpty) return null;

    final png = await _shrinkToPng(Uint8List.fromList(raw));
    if (png == null) return null;

    _memory[url] = png;
    if (file != null) {
      try {
        await file.writeAsBytes(png, flush: true);
      } catch (_) {
        // Sin caché en disco: se vuelve a descargar la próxima vez.
      }
    }
    return png;
  } catch (_) {
    return null;
  }
}

/// Descarga en segundo plano (tras iniciar sesión) para que el primer
/// "Compartir" no tenga que esperar.
Future<void> prefetchCompanyLogo(String? url) async {
  await loadCompanyLogo(url);
}

/// Al cambiar de empresa o cerrar sesión.
void clearCompanyLogoCache() => _memory.clear();

bool _isPng(Uint8List b) =>
    b.length > 8 &&
    b[0] == 0x89 &&
    b[1] == 0x50 &&
    b[2] == 0x4E &&
    b[3] == 0x47;

Future<File?> _cacheFile(String url) async {
  if (kIsWeb) return null;
  try {
    final dir = await getTemporaryDirectory();
    // Hash estable de la URL: cambia si la empresa sube otro logo (otra ruta).
    final key = url.hashCode.toUnsigned(32).toRadixString(16);
    return File('${dir.path}/company_logo_$key.png');
  } catch (_) {
    return null;
  }
}

/// Reduce la imagen a [_targetWidth] px de ancho (si es más grande) y la
/// re-codifica como PNG usando el decodificador de Flutter (sin dependencias).
Future<Uint8List?> _shrinkToPng(Uint8List bytes) async {
  try {
    final codec = await ui.instantiateImageCodec(
      bytes,
      targetWidth: _targetWidth,
      allowUpscaling: false,
    );
    final frame = await codec.getNextFrame();
    final data = await frame.image.toByteData(format: ui.ImageByteFormat.png);
    frame.image.dispose();
    codec.dispose();
    return data?.buffer.asUint8List();
  } catch (_) {
    return null;
  }
}
