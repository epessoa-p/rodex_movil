import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';

/// Servicio del catálogo del taller (gestión completa desde el tab Servicios).
class ServiceItem {
  final int id;
  final String name;
  final double price;
  final String? description;
  final String? estimatedTime;
  final bool active;

  ServiceItem({
    required this.id,
    required this.name,
    required this.price,
    this.description,
    this.estimatedTime,
    required this.active,
  });

  factory ServiceItem.fromJson(Map<String, dynamic> j) => ServiceItem(
    id: j['id'] as int,
    name: (j['name'] ?? '') as String,
    price: (j['price'] as num?)?.toDouble() ?? 0,
    description: j['description'] as String?,
    estimatedTime: j['estimated_time'] as String?,
    active: (j['active'] as bool?) ?? true,
  );
}

class ServicesRepository {
  final ApiClient _api;
  ServicesRepository(this._api);

  /// Catálogo completo (activos primero, luego inactivos).
  Future<List<ServiceItem>> all() async {
    final data = await _api.get('/services');
    final list = ((data as Map<String, dynamic>)['data'] as List?) ?? [];
    return list
        .map((e) => ServiceItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<ServiceItem> create({
    required String name,
    required double price,
    String? description,
    String? estimatedTime,
  }) async {
    final data = await _api.post(
      '/services',
      body: {
        'name': name,
        'price': price,
        'description': ?description,
        'estimated_time': ?estimatedTime,
      },
    );
    final d = (data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    // El alta devuelve solo id/name/price/created: se completa con lo enviado.
    return ServiceItem(
      id: d['id'] as int,
      name: (d['name'] ?? name) as String,
      price: (d['price'] as num?)?.toDouble() ?? price,
      description: description,
      estimatedTime: estimatedTime,
      active: true,
    );
  }

  Future<ServiceItem> update(
    int id, {
    required String name,
    required double price,
    String? description,
    String? estimatedTime,
    bool active = true,
  }) async {
    final data = await _api.put(
      '/services/$id',
      body: {
        'name': name,
        'price': price,
        'description': ?description,
        'estimated_time': ?estimatedTime,
        'active': active,
      },
    );
    return ServiceItem.fromJson((data as Map<String, dynamic>)['data']);
  }
}

final servicesRepositoryProvider = Provider(
  (ref) => ServicesRepository(ref.read(apiClientProvider)),
);

final servicesCatalogProvider = FutureProvider<List<ServiceItem>>(
  (ref) => ref.read(servicesRepositoryProvider).all(),
);
