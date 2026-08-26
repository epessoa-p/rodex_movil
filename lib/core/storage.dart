import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Almacenamiento seguro del token de sesión y la empresa activa.
class SecureStore {
  static const _storage = FlutterSecureStorage();
  static const _kToken = 'auth_token';
  static const _kCompanyId = 'company_id';

  Future<void> saveToken(String token) =>
      _storage.write(key: _kToken, value: token);
  Future<String?> readToken() => _storage.read(key: _kToken);

  Future<void> saveCompanyId(int id) =>
      _storage.write(key: _kCompanyId, value: id.toString());
  Future<int?> readCompanyId() async {
    final v = await _storage.read(key: _kCompanyId);
    return v == null ? null : int.tryParse(v);
  }

  Future<void> clear() async {
    await _storage.delete(key: _kToken);
    await _storage.delete(key: _kCompanyId);
  }
}
