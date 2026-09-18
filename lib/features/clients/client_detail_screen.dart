import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/api_client.dart';
import '../../core/app_toast.dart';
import '../../core/format.dart';
import '../../core/providers.dart';
import '../../core/upper_case.dart';
import '../../core/module_colors.dart';
import '../workshop/work_order_detail_screen.dart';
import 'clients_repository.dart';

/// Ficha del cliente (como en la web): datos de contacto + tabs con su
/// actividad (Ventas, OTs, Vehículos, Citas, Alquileres), cada tab solo si el
/// plan/permiso lo habilita. Edición con `clients.edit`.
class ClientDetailScreen extends ConsumerWidget {
  final int clientId;
  const ClientDetailScreen({super.key, required this.clientId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(clientDetailProvider(clientId));
    final canEdit =
        ref.watch(authControllerProvider).me?.can('clients.edit') ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(async.valueOrNull?.client.fullName ?? 'Cliente'),
        actions: [
          if (canEdit && async.hasValue)
            IconButton(
              tooltip: 'Editar',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () async {
                final saved = await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  showDragHandle: true,
                  builder: (_) => _ClientEditSheet(detail: async.value!),
                );
                if (saved == true) {
                  ref.invalidate(clientDetailProvider(clientId));
                }
              },
            ),
        ],
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('$e', textAlign: TextAlign.center),
          ),
        ),
        data: (d) => _Body(detail: d),
      ),
    );
  }
}

class _Tab {
  final String label;
  final IconData icon;
  final int count;
  final Color color;
  final Widget body;
  const _Tab(this.label, this.icon, this.count, this.color, this.body);
}

class _Body extends StatelessWidget {
  final ClientDetail detail;
  const _Body({required this.detail});

  @override
  Widget build(BuildContext context) {
    final d = detail;
    final tabs = <_Tab>[
      if (d.sales != null)
        _Tab(
          'Ventas',
          Icons.receipt_long_outlined,
          d.sales!.length,
          ModuleColors.sales,
          _ActivityList(rows: d.sales!, empty: 'Sin ventas registradas.'),
        ),
      if (d.workOrders != null)
        _Tab(
          'OTs',
          Icons.build_circle_outlined,
          d.workOrders!.length,
          ModuleColors.workOrders,
          _ActivityList(
            rows: d.workOrders!,
            empty: 'Sin órdenes de taller.',
            onTap: (r) => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => WorkOrderDetailScreen(orderId: r.id),
              ),
            ),
          ),
        ),
      if (d.vehicles != null)
        _Tab(
          'Vehículos',
          Icons.two_wheeler_outlined,
          d.vehicles!.length,
          ModuleColors.vehicles,
          _VehiclesList(rows: d.vehicles!),
        ),
      if (d.appointments != null)
        _Tab(
          'Citas',
          Icons.calendar_month_outlined,
          d.appointments!.length,
          ModuleColors.agenda,
          _ActivityList(rows: d.appointments!, empty: 'Sin citas registradas.'),
        ),
      if (d.rentals != null)
        _Tab(
          'Alquileres',
          Icons.key_outlined,
          d.rentals!.length,
          ModuleColors.rentals,
          _ActivityList(rows: d.rentals!, empty: 'Sin alquileres.'),
        ),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Column(
        children: [
          _InfoCard(detail: d),
          if (tabs.isNotEmpty) ...[
            // Siempre desplazable: con ícono + texto + conteo, 3-4 tabs no
            // caben repartidos en 360 dp (desbordaban).
            // Cada tab con su color: el indicador y la etiqueta activa toman
            // el color del tab actual; el ícono y el contador van siempre en
            // el color del tab (se reconocen aunque no estén activos).
            Builder(
              builder: (ctx) {
                final controller = DefaultTabController.of(ctx);
                return AnimatedBuilder(
                  animation: controller,
                  builder: (_, _) {
                    final active = tabs[controller.index].color;
                    return TabBar(
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      indicatorColor: active,
                      labelColor: ModuleColors.onSoft(active),
                      unselectedLabelColor: Colors.black54,
                      labelStyle: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      tabs: [
                        for (final t in tabs)
                          Tab(
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(t.icon, size: 16, color: t.color),
                                const SizedBox(width: 4),
                                Text(t.label),
                                const SizedBox(width: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 1,
                                  ),
                                  decoration: BoxDecoration(
                                    color: ModuleColors.soft(t.color),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    '${t.count}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: ModuleColors.onSoft(t.color),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    );
                  },
                );
              },
            ),
            Expanded(
              child: TabBarView(children: [for (final t in tabs) t.body]),
            ),
          ] else
            const Expanded(
              child: Center(
                child: Text(
                  'Sin actividad visible para tu perfil.',
                  style: TextStyle(color: Colors.black54),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Datos de contacto con acciones rápidas (llamar / WhatsApp).
class _InfoCard extends StatelessWidget {
  final ClientDetail detail;
  const _InfoCard({required this.detail});

  Future<void> _call(String phone) async {
    await launchUrl(
      Uri.parse('tel:${phone.replaceAll(RegExp(r'[^0-9+]'), '')}'),
    );
  }

  Future<void> _whatsapp(String phone) async {
    var d = phone.replaceAll(RegExp(r'[^0-9]'), '');
    if (d.startsWith('0')) d = d.substring(1);
    if (d.length == 8) d = '591$d';
    await launchUrl(
      Uri.parse('https://wa.me/$d'),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = detail.client;
    final phone = c.phone;
    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 4),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 26,
              backgroundImage: detail.photoUrl != null
                  ? NetworkImage(detail.photoUrl!)
                  : null,
              child: detail.photoUrl == null
                  ? Text(
                      c.fullName.isNotEmpty ? c.fullName[0].toUpperCase() : '?',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    )
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          c.fullName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      if (!detail.active)
                        const Chip(
                          label: Text('Inactivo'),
                          visualDensity: VisualDensity.compact,
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  _line(Icons.badge_outlined, c.idNumber),
                  _line(Icons.phone_outlined, phone),
                  _line(Icons.email_outlined, c.email),
                  _line(Icons.place_outlined, c.address),
                  if (detail.notes != null && detail.notes!.trim().isNotEmpty)
                    _line(Icons.notes_outlined, detail.notes),
                  if (phone != null && phone.trim().isNotEmpty) ...[
                    const SizedBox(height: 6),
                    // Wrap: en 360 dp los dos botones no siempre caben en
                    // una línea junto al avatar (desbordaban).
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _call(phone),
                          icon: const Icon(Icons.call, size: 16),
                          label: const Text('Llamar'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: () => _whatsapp(phone),
                          icon: const Icon(Icons.chat, size: 16),
                          label: const Text('WhatsApp'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: const Color(0xFF128C7E),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _line(IconData icon, String? text) {
    if (text == null || text.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: Colors.black45),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ),
        ],
      ),
    );
  }
}

Color _statusColor(String? status) => switch (status) {
  'recibida' => Colors.blueGrey,
  'diagnosticada' => Colors.indigo,
  'en_proceso' => Colors.orange,
  'terminada' => Colors.green,
  'entregada' => Colors.teal,
  'anulada' || 'cancelada' => Colors.red,
  'programada' => Colors.blue,
  'confirmada' => Colors.indigo,
  'completada' => Colors.green,
  'no_asistio' => Colors.grey,
  'activo' || 'vigente' => Colors.green,
  _ => Colors.blueGrey,
};

class _ActivityList extends StatelessWidget {
  final List<ClientActivity> rows;
  final String empty;
  final void Function(ClientActivity)? onTap;
  const _ActivityList({required this.rows, required this.empty, this.onTap});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return Center(
        child: Text(empty, style: const TextStyle(color: Colors.black54)),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final r = rows[i];
        return ListTile(
          dense: true,
          onTap: onTap == null ? null : () => onTap!(r),
          title: Row(
            children: [
              Expanded(
                child: Text(
                  r.title,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
              if (r.statusLabel != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _statusColor(r.status).withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    r.statusLabel!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _statusColor(r.status),
                    ),
                  ),
                ),
            ],
          ),
          subtitle: Text(
            [
              if (r.subtitle != null && r.subtitle!.isNotEmpty) r.subtitle!,
              if (r.date != null && !r.title.startsWith(r.date!)) _dmy(r.date!),
              if (r.extra != null && r.extra!.isNotEmpty) r.extra!,
            ].join(' · '),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: r.amount != null
              ? Text(
                  money(r.amount!),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                )
              : (onTap != null ? const Icon(Icons.chevron_right) : null),
        );
      },
    );
  }
}

class _VehiclesList extends StatelessWidget {
  final List<ClientVehicle> rows;
  const _VehiclesList({required this.rows});

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Text(
          'Sin vehículos registrados.',
          style: TextStyle(color: Colors.black54),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: rows.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final v = rows[i];
        return ListTile(
          dense: true,
          leading: const Icon(Icons.two_wheeler_outlined),
          title: Text(
            v.label,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            [
              if (v.plate != null && v.plate!.isNotEmpty) 'Placa ${v.plate}',
              if (v.year != null) '${v.year}',
              if (v.color != null && v.color!.isNotEmpty) v.color!,
            ].join(' · '),
          ),
        );
      },
    );
  }
}

String _dmy(String iso) {
  final p = iso.split('-');
  return p.length == 3 ? '${p[2]}/${p[1]}/${p[0]}' : iso;
}

/// Hoja de edición del cliente (mismos campos que la web, sin foto/documentos).
class _ClientEditSheet extends ConsumerStatefulWidget {
  final ClientDetail detail;
  const _ClientEditSheet({required this.detail});

  @override
  ConsumerState<_ClientEditSheet> createState() => _ClientEditSheetState();
}

class _ClientEditSheetState extends ConsumerState<_ClientEditSheet> {
  late final _name = TextEditingController(text: widget.detail.client.fullName);
  late final _idNumber = TextEditingController(
    text: widget.detail.client.idNumber ?? '',
  );
  late final _phone = TextEditingController(
    text: widget.detail.client.phone ?? '',
  );
  late final _email = TextEditingController(
    text: widget.detail.client.email ?? '',
  );
  late final _address = TextEditingController(
    text: widget.detail.client.address ?? '',
  );
  late final _notes = TextEditingController(text: widget.detail.notes ?? '');
  late bool _active = widget.detail.active;
  bool _saving = false;

  @override
  void dispose() {
    for (final c in [_name, _idNumber, _phone, _email, _address, _notes]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      AppToast.error(
        context,
        'El nombre es obligatorio.',
        title: 'Falta el nombre',
      );
      return;
    }
    if (_phone.text.trim().isEmpty) {
      AppToast.error(
        context,
        'El teléfono es obligatorio.',
        title: 'Falta el teléfono',
      );
      return;
    }
    setState(() => _saving = true);
    try {
      String? nz(TextEditingController c) =>
          c.text.trim().isEmpty ? null : c.text.trim();
      await ref
          .read(clientsRepositoryProvider)
          .update(
            widget.detail.client.id,
            fullName: _name.text.trim(),
            phone: _phone.text.trim(),
            idNumber: nz(_idNumber),
            email: nz(_email),
            address: nz(_address),
            notes: nz(_notes),
            active: _active,
          );
      if (!mounted) return;
      AppToast.success(context, 'Cliente actualizado.');
      Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        AppToast.apiError(context, e);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    InputDecoration dec(String label) =>
        InputDecoration(labelText: label, border: const OutlineInputBorder());
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 8, 16, 16 + bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Editar cliente',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: upperCaseFormatters,
              decoration: dec('Nombre completo *'),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _idNumber,
                    textCapitalization: TextCapitalization.characters,
                    inputFormatters: upperCaseFormatters,
                    decoration: dec('Documento'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: dec('Teléfono *'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: dec('Email'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _address,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: upperCaseFormatters,
              decoration: dec('Dirección'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _notes,
              textCapitalization: TextCapitalization.characters,
              inputFormatters: upperCaseFormatters,
              minLines: 2,
              maxLines: 4,
              decoration: dec('Notas'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Activo'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            FilledButton.icon(
              style: FilledButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.check),
              label: const Text('Guardar'),
              onPressed: _saving ? null : _save,
            ),
          ],
        ),
      ),
    );
  }
}
