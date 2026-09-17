import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

/// Envío directo al WhatsApp del cliente (sin pasar por el selector de
/// contactos): texto con `wa.me` y archivos con un intent nativo a WhatsApp.
class WhatsApp {
  WhatsApp._();

  static const _channel = MethodChannel('rodex/whatsapp');

  /// Normaliza el número a formato internacional sin '+' (Bolivia si son 8
  /// dígitos locales). Devuelve null si no hay número usable.
  static String? number(String? phone) {
    if (phone == null) return null;
    var d = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('0')) d = d.substring(1);
    if (d.length == 8) d = '591$d';
    return d.length >= 8 ? d : null;
  }

  /// Abre el chat del número con el mensaje ya escrito. false si no hay
  /// número válido o no se pudo abrir.
  static Future<bool> openChat(String? phone, String text) async {
    final n = number(phone);
    if (n == null) return false;
    final url = Uri.parse('https://wa.me/$n?text=${Uri.encodeComponent(text)}');
    return launchUrl(url, mode: LaunchMode.externalApplication);
  }

  /// Abre WhatsApp en el chat del número con el archivo adjunto (solo
  /// Android). false si no hay número, WhatsApp no está instalado o la
  /// plataforma no lo soporta: el llamador debe usar el compartir genérico.
  static Future<bool> sendFile(
    Uint8List bytes,
    String filename,
    String? phone, {
    String text = '',
    String mime = 'application/pdf',
  }) async {
    final n = number(phone);
    if (n == null) return false;
    if (kIsWeb || !Platform.isAndroid) return false;
    try {
      // Dentro de cache/share_plus para que lo cubra el FileProvider de share_plus.
      final dir = Directory('${(await getTemporaryDirectory()).path}/share_plus');
      await dir.create(recursive: true);
      final file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);
      final ok = await _channel.invokeMethod<bool>('sendFile', {
        'path': file.path,
        'phone': n,
        'text': text,
        'mime': mime,
      });
      return ok ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
