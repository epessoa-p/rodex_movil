import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/module_colors.dart';
import 'quick_service_screen.dart';
import 'reception_screen.dart';
import 'work_order_detail_screen.dart';
import 'workshop_repository.dart';

/// Filtros del listado (valor que entiende el servidor → etiqueta).
const workOrderFilters = <String, String>{
  'activas': 'Activas',
  'por_cobrar': 'Por cobrar',
  '': 'Todas',
  'recibida': 'Recibida',
  'diagnosticada': 'Diagnosticada',
  'en_proceso': 'En proceso',
  'terminada': 'Terminada',
  'entregada': 'Entregada',
};

/// Listado de OTs con buscador y filtro por estado. Con [embedded] = true es
/// un tab del hub "Taller" (sin AppBar propio; el FAB queda dentro del tab).
class WorkOrdersScreen extends ConsumerStatefulWidget {
  final bool embedded;
  const WorkOrdersScreen({super.key, this.embedded = false});

  @override
  ConsumerState<WorkOrdersScreen> createState() => _WorkOrdersScreenState();
}

class _WorkOrdersScreenState extends ConsumerState<WorkOrdersScreen> {
  final _search = TextEditingController();
  Timer? _debounce;

  /// Por defecto "Activas": lo que está en el taller ahora.
  String _status = 'activas';
  String _q = '';

  (String, String) get _key => (_status, _q);

  @override
  void dispose() {
    _debounce?.cancel();
    _search.dispose();
    super.dispose();
  }

  void _onSearch(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () {
      if (mounted && v.trim() != _q) setState(() => _q = v.trim());
    });
  }

  void _refresh() => ref.invalidate(workOrdersProvider(_key));

  static Color _statusColor(String status) => switch (status) {
    'recibida' => Colors.blueGrey,
    'diagnosticada' => Colors.indigo,
    'en_proceso' => Colors.orange,
    'terminada' => Colors.green,
    'entregada' => Colors.teal,
    'anulada' => Colors.red,
    _ => Colors.grey,
  };

  String get _emptyText {
    if (_q.isNotEmpty) return 'Sin órdenes que coincidan con «$_q».';
    return switch (_status) {
      'activas' => 'No hay órdenes activas.',
      'por_cobrar' => 'No hay órdenes con saldo por cobrar.',
      '' => 'No hay órdenes.',
      _ => 'No hay órdenes «${workOrderFilters[_status]}».',
    };
  }

  @override
  Widget build(BuildContext context) {
    final orders = ref.watch(workOrdersProvider(_key));

    return Scaffold(
      appBar: widget.embedded
          ? null
          : AppBar(title: const Text('Órdenes de trabajo')),
      // Dos botones directos: servicio rápido (al paso) y recepción completa.
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton.extended(
            heroTag: 'fab-quick-service',
            backgroundColor: const Color(0xFFFFF3E0),
            foregroundColor: Colors.orange.shade900,
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const QuickServiceScreen()),
              );
              _refresh();
            },
            icon: const Icon(Icons.bolt),
            label: const Text('Servicio rápido'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton.extended(
            heroTag: 'fab-work-orders',
            backgroundColor: ModuleColors.soft(ModuleColors.workOrders),
            foregroundColor: ModuleColors.onSoft(ModuleColors.workOrders),
            onPressed: () async {
              final created = await Navigator.of(context).push<bool>(
                MaterialPageRoute(builder: (_) => const ReceptionScreen()),
              );
              if (created == true) _refresh();
            },
            icon: const Icon(Icons.add),
            label: const Text('Nueva OT'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Buscador
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              key: const Key('wo_search'),
              controller: _search,
              onChanged: _onSearch,
              textInputAction: TextInputAction.search,
              decoration: InputDecoration(
                isDense: true,
                hintText: 'Buscar por código, cliente, teléfono o placa',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Limpiar',
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _search.clear();
                          _debounce?.cancel();
                          setState(() => _q = '');
                        },
                      ),
                border: const OutlineInputBorder(),
              ),
            ),
          ),
          // Estados (fila desplazable)
          SizedBox(
            height: 46,
            child: ListView(
              key: const Key('wo_filters'),
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              children: [
                for (final e in workOrderFilters.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text(e.value),
                      selected: _status == e.key,
                      visualDensity: VisualDensity.compact,
                      onSelected: (_) => setState(() => _status = e.key),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: orders.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => ListView(
                  children: [
                    const SizedBox(height: 80),
                    Center(child: Text('$e')),
                  ],
                ),
                data: (list) => list.isEmpty
                    ? ListView(
                        children: [
                          const SizedBox(height: 100),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 24),
                            child: Text(
                              _emptyText,
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.black54),
                            ),
                          ),
                        ],
                      )
                    : ListView.separated(
                        // Espacio al final para los dos botones flotantes.
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 140),
                        itemCount: list.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (context, i) {
                          final o = list[i];
                          return Card(
                            child: ListTile(
                              // El chip va en Flexible: código + estado largo
                              // ("Diagnosticada") desbordaban la fila en pantallas
                              // de 360 dp. En debug ese overflow se imprime en cada
                              // frame y congela la app (ANR); en release solo se ve.
                              title: Row(
                                children: [
                                  Text(
                                    o.code,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: _StatusChip(
                                      label: o.statusLabel,
                                      color: _statusColor(o.status),
                                    ),
                                  ),
                                ],
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    [
                                      o.client ?? 'Cliente de paso',
                                      if (o.vehicle != null &&
                                          o.vehicle!.isNotEmpty)
                                        o.vehicle!,
                                      if (o.isQuick) '⚡ rápida',
                                    ].join(' · '),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  if (o.total > 0)
                                    Text(
                                      o.balance > 0.005
                                          ? 'Total ${money(o.total)} · debe ${money(o.balance)}'
                                          : 'Total ${money(o.total)}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                ],
                              ),
                              trailing: const Icon(Icons.chevron_right),
                              isThreeLine: o.total > 0,
                              onTap: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        WorkOrderDetailScreen(orderId: o.id),
                                  ),
                                );
                                _refresh();
                              },
                            ),
                          );
                        },
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusChip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
