import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/module_colors.dart';
import '../../core/providers.dart';

/// Tipos de catálogo del hub Inventario (coinciden con la API `/catalogs/{type}`).
enum CatalogType {
  categories('categories', 'Categorías', 'Categoría', 'product-categories'),
  brands('brands', 'Marcas', 'Marca', 'product-brands'),
  motoModels('moto-models', 'Modelos', 'Modelo de moto', 'moto-models'),
  motoBrands('moto-brands', 'Marcas de moto', 'Marca de moto', 'moto-brands'),
  origins('origins', 'Orígenes', 'Origen', 'product-origins');

  const CatalogType(this.path, this.title, this.singular, this.module);
  final String path;
  final String title;
  final String singular;

  /// Módulo de permisos (`<module>.view/create/edit`).
  final String module;

  /// Color distintivo del catálogo (tab del hub, avatares, FAB).
  Color get color => switch (this) {
    CatalogType.categories => ModuleColors.categories,
    CatalogType.brands => ModuleColors.brands,
    CatalogType.motoModels => ModuleColors.models,
    CatalogType.motoBrands => ModuleColors.models,
    CatalogType.origins => ModuleColors.origins,
  };
}

/// Registro de un catálogo. Los campos extra dependen del tipo.
class CatalogItem {
  final int id;
  final String name;
  final bool active;
  final String? description; // categorías, marcas
  final String? country; // marcas de moto
  final int? motoBrandId; // modelos
  final String? brand; // modelos: nombre de la marca
  final String? engineCc;
  final int? year;
  final double? suggestedPrice;

  const CatalogItem({
    required this.id,
    required this.name,
    this.active = true,
    this.description,
    this.country,
    this.motoBrandId,
    this.brand,
    this.engineCc,
    this.year,
    this.suggestedPrice,
  });

  factory CatalogItem.fromJson(Map<String, dynamic> j) => CatalogItem(
    id: j['id'] as int,
    name: (j['name'] ?? '') as String,
    active: (j['active'] as bool?) ?? true,
    description: j['description'] as String?,
    country: j['country'] as String?,
    motoBrandId: (j['moto_brand_id'] as num?)?.toInt(),
    brand: j['brand'] as String?,
    engineCc: j['engine_cc'] as String?,
    year: (j['year'] as num?)?.toInt(),
    suggestedPrice: (j['suggested_price'] as num?)?.toDouble(),
  );

  /// Texto secundario para el listado.
  String get subtitle => [
    if (brand != null && brand!.isNotEmpty) brand!,
    if (engineCc != null && engineCc!.isNotEmpty) engineCc!,
    if (year != null) '$year',
    if (country != null && country!.isNotEmpty) country!,
    if (description != null && description!.isNotEmpty) description!,
    if (!active) 'inactivo',
  ].join(' · ');
}

class CatalogsRepository {
  final ApiClient _api;
  CatalogsRepository(this._api);

  Future<List<CatalogItem>> list(CatalogType type, {String q = ''}) async {
    final data = await _api.get('/catalogs/${type.path}', query: {'q': q});
    final list = ((data as Map<String, dynamic>)['data'] as List?) ?? [];
    return list
        .map((e) => CatalogItem.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  /// Alta; si ya existe con ese nombre el backend lo reutiliza (y reactiva).
  Future<CatalogItem> create(
    CatalogType type, {
    required String name,
    Map<String, dynamic> extra = const {},
  }) async {
    final data = await _api.post(
      '/catalogs/${type.path}',
      body: {'name': name, ...extra},
    );
    return CatalogItem.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<CatalogItem> update(
    CatalogType type,
    int id, {
    required String name,
    bool active = true,
    Map<String, dynamic> extra = const {},
  }) async {
    final data = await _api.put(
      '/catalogs/${type.path}/$id',
      body: {'name': name, 'active': active, ...extra},
    );
    return CatalogItem.fromJson((data as Map<String, dynamic>)['data']);
  }
}

final catalogsRepositoryProvider = Provider(
  (ref) => CatalogsRepository(ref.read(apiClientProvider)),
);

/// Listado por tipo (se invalida tras crear/editar).
final catalogListProvider =
    FutureProvider.family<List<CatalogItem>, CatalogType>(
      (ref, type) => ref.read(catalogsRepositoryProvider).list(type),
    );
