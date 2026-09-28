// Caché en disco para las miniaturas de productos.
//
// Flutter no guarda las imágenes de red en disco: al cerrar la app se pierden
// y el listado vuelve a descargarlas todas. Aquí se guardan tal cual llegan
// (ya vienen reducidas del servidor, ~20 KB) y así, a partir de la segunda
// vez, el listado se pinta sin red y sin gastar datos.
//
// Mismo patrón que [loadCompanyLogo]: Dio directo, porque las URLs de
// `/storage` son públicas y no llevan token. Cualquier fallo devuelve null y
// la fila muestra el marcador; nunca lanza.

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

/// Miniaturas en RAM (tope por cantidad: cada una pesa decenas de KB).
const _memoryLimit = 60;
final Map<String, Uint8List> _memory = {};

/// Podas del directorio: se conserva lo más reciente.
const _maxFiles = 400;
const _maxBytes = 30 * 1024 * 1024;

const _dirName = 'img_thumbs';
bool _pruned = false;

typedef ThumbLoader = Future<Uint8List?> Function(String url);

/// Bytes de la miniatura de [url] (memoria → disco → red).
Future<Uint8List?> loadThumb(String url) async {
  if (url.trim().isEmpty) return null;

  final cached = _memory[url];
  if (cached != null) return cached;

  try {
    final file = await _cacheFile(url);
    if (file != null && await file.exists()) {
      final bytes = await file.readAsBytes();
      if (bytes.isNotEmpty) {
        _remember(url, bytes);
        return bytes;
      }
      await file.delete();
    }

    final res = await Dio().get<List<int>>(
      url,
      options: Options(
        responseType: ResponseType.bytes,
        receiveTimeout: const Duration(seconds: 10),
        sendTimeout: const Duration(seconds: 10),
      ),
    );
    final raw = res.data;
    if (raw == null || raw.isEmpty) return null;

    final bytes = Uint8List.fromList(raw);
    _remember(url, bytes);
    if (file != null) {
      try {
        await file.writeAsBytes(bytes, flush: true);
      } catch (_) {
        // Sin espacio o sin permisos: se vuelve a descargar la próxima vez.
      }
    }
    return bytes;
  } catch (_) {
    return null;
  }
}

void _remember(String url, Uint8List bytes) {
  if (_memory.length >= _memoryLimit) {
    _memory.remove(_memory.keys.first); // la más antigua
  }
  _memory[url] = bytes;
}

/// Limpia la caché en RAM (al cambiar de empresa o cerrar sesión).
void clearThumbMemoryCache() => _memory.clear();

/// Poda el directorio si creció de más. Se llama una vez por sesión, al abrir
/// el listado; si falla, no pasa nada (la caché sigue sirviendo).
Future<void> pruneThumbCache() async {
  if (_pruned || kIsWeb) return;
  _pruned = true;
  try {
    final dir = await _cacheDir();
    if (dir == null || !await dir.exists()) return;

    final files = <File>[];
    await for (final e in dir.list()) {
      if (e is File) files.add(e);
    }

    var total = 0;
    for (final f in files) {
      total += await f.length();
    }
    if (files.length <= _maxFiles && total <= _maxBytes) return;

    // Más viejas primero: se borran hasta volver a la mitad del tope.
    files.sort(
      (a, b) => a.statSync().modified.compareTo(b.statSync().modified),
    );
    for (final f in files) {
      if (files.length <= _maxFiles ~/ 2 && total <= _maxBytes ~/ 2) break;
      total -= await f.length();
      await f.delete();
      if (total <= _maxBytes ~/ 2) break;
    }
  } catch (_) {
    // Nada: la caché no es crítica.
  }
}

Future<Directory?> _cacheDir() async {
  if (kIsWeb) return null;
  try {
    final tmp = await getTemporaryDirectory();
    final dir = Directory('${tmp.path}/$_dirName');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  } catch (_) {
    return null;
  }
}

Future<File?> _cacheFile(String url) async {
  final dir = await _cacheDir();
  if (dir == null) return null;
  // La ruta del archivo cambia con cada foto subida, así que el hash de la URL
  // alcanza como clave: una foto nueva nunca reusa la entrada de la anterior.
  final key = url.hashCode.toUnsigned(32).toRadixString(16);
  return File('${dir.path}/$key');
}
