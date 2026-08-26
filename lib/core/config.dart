/// Configuración global de la app.
class AppConfig {
  // ── URL base de la API de rodex_web ───────────────────────────────────────
  // Para cambiar de entorno: comenta la línea ACTIVA de `_defaultApiBaseUrl`
  // y descomenta SOLO UNA de las alternativas (debe quedar una sola activa).
  //
  // También se puede sobreescribir sin tocar el código al compilar:
  //   flutter run --dart-define=API_BASE_URL=https://mi-host/api

  // PRODUCCIÓN (activa):
  static const String _defaultApiBaseUrl = 'https://rodex.sczsoft.net/api';

  // ── PRUEBAS LOCALES (descomenta la que uses y comenta la de producción) ──
  // Emulador Android (10.0.2.2 = localhost de la PC):
  // static const String _defaultApiBaseUrl = 'http://10.0.2.2:8000/api';
  //
  // Celular físico en la MISMA red Wi-Fi (usa tu IP de LAN, ver `ipconfig`
  // adaptador Wi-Fi; el backend debe correr con --host=0.0.0.0):
  // static const String _defaultApiBaseUrl = 'http://192.168.0.35:8060/api';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: _defaultApiBaseUrl,
  );

  static const String appName = 'Rodex Móvil';

  /// Versión visible en Ajustes (mantener en sync con pubspec.yaml `version:`).
  static const String appVersion = '1.0.0';
}
