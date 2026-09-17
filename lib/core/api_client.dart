import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'config.dart';

/// Error normalizado de la API (mensaje legible + código HTTP + code de negocio).
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final String? code;
  final Map<String, dynamic>? data;

  ApiException(this.message, {this.statusCode, this.code, this.data});

  bool get isUnauthorized => statusCode == 401;
  bool get needsCompany => statusCode == 409 && code == 'company_required';

  @override
  String toString() => message;
}

/// Cliente HTTP hacia la API de rodex_web.
///
/// Inyecta `Authorization: Bearer <token>` y `X-Company-Id` en cada petición,
/// y traduce los errores a [ApiException]. El token y la empresa activa se
/// fijan tras el login (setSession) y se limpian al cerrar sesión (clearSession).
class ApiClient {
  final Dio _dio;
  String? _token;
  int? _companyId;

  /// Se dispara ante cualquier 401 con token puesto (sesión vencida, usuario
  /// desactivado, token revocado). Lo registra AuthController para cerrar
  /// sesión y llevar al login con el motivo. No aplica a /login.
  void Function(ApiException e)? onUnauthorized;

  ApiClient() : _dio = Dio(BaseOptions(baseUrl: AppConfig.apiBaseUrl)) {
    _dio.options.headers['Accept'] = 'application/json';
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 20);

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          if (_token != null) {
            options.headers['Authorization'] = 'Bearer $_token';
          }
          if (_companyId != null) {
            options.headers['X-Company-Id'] = _companyId.toString();
          }
          handler.next(options);
        },
      ),
    );
  }

  void setSession({String? token, int? companyId}) {
    if (token != null) _token = token;
    if (companyId != null) _companyId = companyId;
  }

  void setCompany(int companyId) => _companyId = companyId;

  void clearSession() {
    _token = null;
    _companyId = null;
  }

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _request(() => _dio.get(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? body}) =>
      _request(() => _dio.post(path, data: body));

  Future<dynamic> put(String path, {Object? body}) =>
      _request(() => _dio.put(path, data: body));

  Future<dynamic> delete(String path, {Object? body}) =>
      _request(() => _dio.delete(path, data: body));

  /// Solo para tests: ejecuta [run] con el mismo manejo de errores (401 → hook).
  @visibleForTesting
  Future<dynamic> runForTest(Future<Response> Function() run) => _request(run);

  Future<dynamic> _request(Future<Response> Function() run) async {
    try {
      final res = await run();
      return res.data;
    } on DioException catch (e) {
      final ex = _toApiException(e);
      final path = e.requestOptions.path;
      if (ex.isUnauthorized && _token != null && !path.endsWith('/login')) {
        // La sesión ya no vale: se limpia y se avisa (una sola vez).
        _token = null;
        _companyId = null;
        onUnauthorized?.call(ex);
      }
      throw ex;
    }
  }

  ApiException _toApiException(DioException e) {
    final status = e.response?.statusCode;
    final data = e.response?.data;

    if (data is Map<String, dynamic>) {
      final msg = (data['message'] as String?) ?? 'Ocurrió un error.';
      return ApiException(
        msg,
        statusCode: status,
        code: data['code'] as String?,
        data: data,
      );
    }

    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.connectionError) {
      return ApiException(
        'No se pudo conectar con el servidor. Revisa tu conexión.',
        statusCode: status,
      );
    }

    return ApiException('Ocurrió un error inesperado.', statusCode: status);
  }
}
