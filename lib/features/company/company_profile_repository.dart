import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';

/// Datos editables de la empresa activa.
class CompanyProfile {
  final int id;
  final String name;
  final String? phone;
  final String? address;
  final String? logoUrl;
  final int trackingLinkDays;
  final String dashboardOrder;

  CompanyProfile({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.logoUrl,
    required this.trackingLinkDays,
    this.dashboardOrder = 'ventas,taller,compras',
  });

  factory CompanyProfile.fromJson(Map<String, dynamic> j) => CompanyProfile(
        id: j['id'] as int,
        name: (j['name'] ?? '') as String,
        phone: j['phone'] as String?,
        address: j['address'] as String?,
        logoUrl: j['logo_url'] as String?,
        trackingLinkDays: (j['tracking_link_days'] as num?)?.toInt() ?? 1,
        dashboardOrder:
            (j['dashboard_order'] as String?)?.trim().isNotEmpty == true
                ? (j['dashboard_order'] as String).trim()
                : 'ventas,taller,compras',
      );
}

class CompanyProfileRepository {
  final ApiClient _api;
  CompanyProfileRepository(this._api);

  Future<CompanyProfile> get() async {
    final data = await _api.get('/company-profile');
    return CompanyProfile.fromJson((data as Map<String, dynamic>)['data']);
  }

  /// Actualiza los datos. `logoPath` opcional (ruta local de la nueva foto).
  Future<CompanyProfile> update({
    String? phone,
    String? address,
    required int trackingLinkDays,
    String? dashboardOrder,
    String? logoPath,
  }) async {
    final form = FormData.fromMap({
      'phone': phone ?? '',
      'address': address ?? '',
      'tracking_link_days': trackingLinkDays,
      'dashboard_order': ?dashboardOrder,
    });
    if (logoPath != null) {
      form.files.add(MapEntry(
        'logo',
        await MultipartFile.fromFile(logoPath,
            filename: logoPath.split(RegExp(r'[\\/]')).last),
      ));
    }
    final data = await _api.post('/company-profile', body: form);
    return CompanyProfile.fromJson((data as Map<String, dynamic>)['data']);
  }
}

final companyProfileRepositoryProvider = Provider<CompanyProfileRepository>(
  (ref) => CompanyProfileRepository(ref.read(apiClientProvider)),
);

final companyProfileProvider = FutureProvider<CompanyProfile>(
  (ref) => ref.read(companyProfileRepositoryProvider).get(),
);
