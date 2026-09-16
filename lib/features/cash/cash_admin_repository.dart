import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';

/// Opción simple id + nombre (sucursal / personal).
class NamedOption {
  final int id;
  final String name;

  NamedOption({required this.id, required this.name});

  factory NamedOption.fromJson(Map<String, dynamic> j) =>
      NamedOption(id: j['id'] as int, name: (j['name'] ?? '') as String);
}

/// Par (sucursal, personal) que ya tiene caja. Regla: UNA caja por sucursal
/// POR PERSONAL (un personal puede tener varias cajas en sucursales distintas).
class TakenPair {
  final int registerId;
  final int branchId;
  final int personalId;
  TakenPair({
    required this.registerId,
    required this.branchId,
    required this.personalId,
  });

  factory TakenPair.fromJson(Map<String, dynamic> j) => TakenPair(
    registerId: j['register_id'] as int,
    branchId: j['branch_id'] as int,
    personalId: j['personal_id'] as int,
  );
}

/// Caja (para administración: crear/asignar a personal).
class CashRegisterAdmin {
  final int id;
  final String name;
  final String? description;
  final String? branch;
  final int? branchId;
  final String? personal;
  final int? personalId;
  final bool active;
  final bool hasSession;

  /// Con sesiones o movimientos registrados la caja ya no se edita.
  final bool hasRecords;

  CashRegisterAdmin({
    required this.id,
    required this.name,
    this.description,
    this.branch,
    this.branchId,
    this.personal,
    this.personalId,
    required this.active,
    required this.hasSession,
    this.hasRecords = false,
  });

  factory CashRegisterAdmin.fromJson(Map<String, dynamic> j) =>
      CashRegisterAdmin(
        id: j['id'] as int,
        name: (j['name'] ?? '') as String,
        description: j['description'] as String?,
        branch: j['branch'] as String?,
        branchId: j['branch_id'] as int?,
        personal: j['personal'] as String?,
        personalId: j['assigned_personal_id'] as int?,
        active: (j['active'] ?? true) as bool,
        hasSession: (j['has_session'] ?? false) as bool,
        hasRecords: (j['has_records'] ?? false) as bool,
      );
}

class CashRegisterFormData {
  final List<NamedOption> branches;
  final List<NamedOption> personal;
  final List<TakenPair> taken;
  CashRegisterFormData({
    required this.branches,
    required this.personal,
    this.taken = const [],
  });

  /// Sucursales donde [personalId] todavía NO tiene caja (o la que ya ocupa
  /// la caja [exceptRegisterId] que se está editando).
  List<NamedOption> freeBranchesFor(int? personalId, {int? exceptRegisterId}) {
    if (personalId == null) return branches;
    return branches
        .where(
          (b) => !taken.any(
            (t) =>
                t.branchId == b.id &&
                t.personalId == personalId &&
                t.registerId != exceptRegisterId,
          ),
        )
        .toList();
  }
}

class CashAdminRepository {
  final ApiClient _api;
  CashAdminRepository(this._api);

  Future<List<CashRegisterAdmin>> registers() async {
    final data = await _api.get('/cash-registers');
    return (((data as Map<String, dynamic>)['data'] as List?) ?? [])
        .map((e) => CashRegisterAdmin.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<CashRegisterFormData> formData() async {
    final data = await _api.get('/cash-registers/form-data');
    final d = (data as Map<String, dynamic>)['data'] as Map<String, dynamic>;
    List<NamedOption> opts(String k) => ((d[k] as List?) ?? [])
        .map((e) => NamedOption.fromJson(e as Map<String, dynamic>))
        .toList();
    return CashRegisterFormData(
      branches: opts('branches'),
      personal: opts('personal'),
      taken: ((d['taken'] as List?) ?? [])
          .map((e) => TakenPair.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  Future<CashRegisterAdmin> create({
    required int branchId,
    required String name,
    required int assignedPersonalId,
    String? description,
    bool active = true,
  }) async {
    final data = await _api.post(
      '/cash-registers',
      body: {
        'branch_id': branchId,
        'name': name,
        'assigned_personal_id': assignedPersonalId,
        'description': ?description,
        'active': active,
      },
    );
    return CashRegisterAdmin.fromJson((data as Map<String, dynamic>)['data']);
  }

  Future<CashRegisterAdmin> update(
    int id, {
    required int branchId,
    required String name,
    required int assignedPersonalId,
    String? description,
    bool active = true,
  }) async {
    final data = await _api.put(
      '/cash-registers/$id',
      body: {
        'branch_id': branchId,
        'name': name,
        'assigned_personal_id': assignedPersonalId,
        'description': ?description,
        'active': active,
      },
    );
    return CashRegisterAdmin.fromJson((data as Map<String, dynamic>)['data']);
  }
}

final cashAdminRepositoryProvider = Provider<CashAdminRepository>(
  (ref) => CashAdminRepository(ref.read(apiClientProvider)),
);
