import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import 'mechanic_payment_detail_screen.dart';
import 'mechanic_payments_repository.dart';

/// Pago a mecánicos: lista de mecánicos con su pendiente; abre el detalle por OT.
class MechanicPaymentsScreen extends ConsumerWidget {
  const MechanicPaymentsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(mechanicPaymentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pago a mecánicos')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(mechanicPaymentsProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 80),
            Center(child: Text('$e', textAlign: TextAlign.center)),
          ]),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 80),
                Center(child: Text('No hay mecánicos con comisiones.')),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: list.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (_, i) {
                final m = list[i];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: (m.pending > 0 ? Colors.red : Colors.green)
                          .withValues(alpha: .12),
                      child: Icon(Icons.engineering_outlined,
                          color: m.pending > 0 ? Colors.red : Colors.green),
                    ),
                    title: Text(m.name,
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${_trim(m.commissionRate)}% · ${m.pendingCount} OT(s) pendientes · Pagado ${money(m.paid)}'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        const Text('Pendiente',
                            style:
                                TextStyle(fontSize: 10, color: Colors.black54)),
                        Text(money(m.pending),
                            style: TextStyle(
                                fontWeight: FontWeight.w800,
                                color:
                                    m.pending > 0 ? Colors.red : Colors.green)),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(MaterialPageRoute(
                        builder: (_) =>
                            MechanicPaymentDetailScreen(mechanicId: m.id),
                      ));
                      ref.invalidate(mechanicPaymentsProvider);
                    },
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  static String _trim(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();
}
