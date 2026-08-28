import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import 'reception_screen.dart';
import 'work_order_detail_screen.dart';
import 'workshop_repository.dart';

class WorkOrdersScreen extends ConsumerWidget {
  const WorkOrdersScreen({super.key});

  Color _statusColor(String status) => switch (status) {
        'recibida' => Colors.blueGrey,
        'diagnosticada' => Colors.indigo,
        'en_proceso' => Colors.orange,
        'terminada' => Colors.green,
        'entregada' => Colors.teal,
        'anulada' => Colors.red,
        _ => Colors.grey,
      };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final orders = ref.watch(workOrdersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Taller')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const ReceptionScreen()),
          );
          if (created == true) ref.invalidate(workOrdersProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva OT'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(workOrdersProvider),
        child: orders.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 80),
            Center(child: Text('$e')),
          ]),
          data: (list) => list.isEmpty
              ? ListView(children: const [
                  SizedBox(height: 120),
                  Center(child: Text('No hay órdenes activas.')),
                ])
              : ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: list.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final o = list[i];
                    return Card(
                      child: ListTile(
                        title: Row(
                          children: [
                            Text(o.code,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700)),
                            const SizedBox(width: 8),
                            _StatusChip(
                                label: o.statusLabel,
                                color: _statusColor(o.status)),
                          ],
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('${o.client ?? ''} · ${o.vehicle ?? ''}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            if (o.total > 0)
                              Text('Total ${money(o.total)}',
                                  style: const TextStyle(fontSize: 12)),
                          ],
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        isThreeLine: o.total > 0,
                        onTap: () async {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                                builder: (_) =>
                                    WorkOrderDetailScreen(orderId: o.id)),
                          );
                          ref.invalidate(workOrdersProvider);
                        },
                      ),
                    );
                  },
                ),
        ),
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
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w600)),
    );
  }
}
