import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/format.dart';
import '../../core/module_colors.dart';
import 'inventory_report_repository.dart';

/// Reporte de inventario: valorización (productos, unidades, valor a costo,
/// valor a venta, ganancia potencial) consolidada o por almacén, con
/// desglose por categoría y productos bajo el stock mínimo.
class InventoryReportScreen extends ConsumerStatefulWidget {
  const InventoryReportScreen({super.key});

  @override
  ConsumerState<InventoryReportScreen> createState() =>
      _InventoryReportScreenState();
}

class _InventoryReportScreenState extends ConsumerState<InventoryReportScreen> {
  int _warehouse = 0; // 0 = todos

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(inventoryReportProvider(_warehouse));
    return Scaffold(
      appBar: AppBar(title: const Text('Inventario')),
      body: RefreshIndicator(
        onRefresh: () async =>
            ref.invalidate(inventoryReportProvider(_warehouse)),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(
            children: [
              const SizedBox(height: 80),
              Center(child: Text('$e', textAlign: TextAlign.center)),
            ],
          ),
          data: (r) {
            final maxCat = r.byCategory.isEmpty
                ? 0.0
                : r.byCategory
                      .map((c) => c.valuePrice)
                      .reduce((a, b) => a > b ? a : b);
            return ListView(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
              children: [
                if (r.warehouses.length > 1)
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _chip('Todos los almacenes', 0),
                        for (final w in r.warehouses) _chip(w.name, w.id),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                _KpiGrid(r: r),
                if (r.byCategory.isNotEmpty) ...[
                  const SizedBox(height: 14),
                  const _SectionTitle('Por categoría'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                      child: Column(
                        children: [
                          for (final c in r.byCategory)
                            _CategoryRow(c: c, max: maxCat),
                        ],
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                _SectionTitle('Stock bajo (${r.lowStock.length})'),
                if (r.lowStock.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(14),
                      child: Text(
                        'Ningún producto por debajo de su mínimo.',
                        style: TextStyle(color: Colors.black54),
                      ),
                    ),
                  )
                else
                  Card(
                    child: Column(
                      children: [
                        for (var i = 0; i < r.lowStock.length; i++) ...[
                          if (i > 0) const Divider(height: 1),
                          _LowStockTile(p: r.lowStock[i]),
                        ],
                      ],
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _chip(String label, int id) => Padding(
    padding: const EdgeInsets.only(right: 6),
    child: ChoiceChip(
      label: Text(label),
      selected: _warehouse == id,
      visualDensity: VisualDensity.compact,
      onSelected: (_) => setState(() => _warehouse = id),
    ),
  );
}

class _KpiGrid extends StatelessWidget {
  final InventoryReport r;
  const _KpiGrid({required this.r});

  @override
  Widget build(BuildContext context) {
    Widget card(
      String label,
      String value,
      IconData icon, {
      Color? color,
      bool dark = false,
    }) => Card(
      margin: EdgeInsets.zero,
      color: dark ? const Color(0xFF1F2937) : null,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  size: 14,
                  color: dark ? Colors.white70 : Colors.black45,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: Text(
                    label.toUpperCase(),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: dark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w800,
                  color: dark ? Colors.white : (color ?? Colors.black87),
                ),
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: card(
                'Productos',
                '${r.productCount}',
                Icons.inventory_2_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: card('Unidades', qty(r.totalUnits), Icons.layers_outlined),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: card(
                'Valor a costo',
                money(r.valueCost),
                Icons.receipt_long_outlined,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: card(
                'Valor a venta',
                money(r.valuePrice),
                Icons.sell_outlined,
                color: ModuleColors.sales.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        card(
          'Ganancia potencial',
          money(r.potentialProfit),
          Icons.trending_up,
          dark: true,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 4, 4, 6),
    child: Text(
      text,
      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
    ),
  );
}

class _CategoryRow extends StatelessWidget {
  final CategoryValuation c;
  final double max;
  const _CategoryRow({required this.c, required this.max});

  @override
  Widget build(BuildContext context) {
    final ratio = max <= 0 ? 0.0 : (c.valuePrice / max).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  c.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 13),
                ),
              ),
              Text(
                money(c.valuePrice),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${c.products} producto${c.products == 1 ? '' : 's'} · ${qty(c.units)} unid. · costo ${money(c.valueCost)}',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 6,
              backgroundColor: ModuleColors.soft(ModuleColors.products),
              color: ModuleColors.products,
            ),
          ),
        ],
      ),
    );
  }
}

class _LowStockTile extends StatelessWidget {
  final LowStockRow p;
  const _LowStockTile({required this.p});

  @override
  Widget build(BuildContext context) {
    final out = p.stock <= 0;
    final color = out ? Colors.red.shade700 : Colors.orange.shade800;
    return ListTile(
      dense: true,
      leading: Icon(
        out ? Icons.error_outline : Icons.warning_amber_rounded,
        color: color,
      ),
      title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(p.sku ?? ''),
      trailing: Text(
        '${qty(p.stock)} / mín. ${p.minStock}${p.unit != null ? ' ${p.unit}' : ''}',
        style: TextStyle(fontWeight: FontWeight.w700, color: color),
      ),
    );
  }
}
