import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';

/// Sucursal (alcance móvil: solo datos de contacto).
class BranchInfo {
  final int id;
  final String name;
  final String? address;
  final String? phone;
  final bool active;

  BranchInfo({
    required this.id,
    required this.name,
    this.address,
    this.phone,
    required this.active,
  });

  factory BranchInfo.fromJson(Map<String, dynamic> j) => BranchInfo(
        id: j['id'] as int,
        name: (j['name'] ?? '') as String,
        address: j['address'] as String?,
        phone: j['phone'] as String?,
        active: (j['active'] ?? true) as bool,
      );
}

class BranchesRepository {
  final ApiClient _api;
  BranchesRepository(this._api);

  Future<List<BranchInfo>> list() async {
    final data = await _api.get('/branches');
    return (((data as Map<String, dynamic>)['data'] as List?) ?? [])
        .map((e) => BranchInfo.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Edita solo nombre, dirección y teléfono (el resto es exclusivo de la web).
  Future<BranchInfo> update(
    int id, {
    required String name,
    String? address,
    String? phone,
  }) async {
    final data = await _api.put('/branches/$id', body: {
      'name': name,
      'address': address ?? '',
      'phone': phone ?? '',
    });
    return BranchInfo.fromJson((data as Map<String, dynamic>)['data']);
  }
}

final branchesRepositoryProvider = Provider<BranchesRepository>(
  (ref) => BranchesRepository(ref.read(apiClientProvider)),
);
