import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../products/products_screen.dart';
import 'catalog_screen.dart';
import 'catalogs_repository.dart';

/// Hub "Inventario": Productos · Categorías · Marcas · Modelos · Orígenes.
/// A diferencia de otros hubs, cada tab se construye **la primera vez que se
/// abre** (y se conserva después): así entrar a Inventario solo carga la
/// lista de productos, no los cinco catálogos.
class InventoryHubScreen extends ConsumerStatefulWidget {
  const InventoryHubScreen({super.key});

  @override
  ConsumerState<InventoryHubScreen> createState() => _InventoryHubScreenState();
}

class _Tab {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget Function() build;
  const _Tab(this.label, this.icon, this.selectedIcon, this.build);
}

class _InventoryHubScreenState extends ConsumerState<InventoryHubScreen> {
  int _index = 0;
  final _visited = <int>{0};

  List<_Tab> _tabs(MeContext me) => [
    if (me.canAny(['products.view', 'pos.access', 'sales.view']))
      _Tab(
        'Productos',
        Icons.inventory_2_outlined,
        Icons.inventory_2,
        () => const ProductsScreen(embedded: true),
      ),
    if (me.can('product-categories.view'))
      _Tab(
        'Categorías',
        Icons.category_outlined,
        Icons.category,
        () => const CatalogScreen(type: CatalogType.categories, embedded: true),
      ),
    if (me.can('product-brands.view'))
      _Tab(
        'Marcas',
        Icons.sell_outlined,
        Icons.sell,
        () => const CatalogScreen(type: CatalogType.brands, embedded: true),
      ),
    if (me.can('moto-models.view'))
      _Tab(
        'Modelos',
        Icons.two_wheeler_outlined,
        Icons.two_wheeler,
        () => const CatalogScreen(type: CatalogType.motoModels, embedded: true),
      ),
    if (me.can('product-origins.view'))
      _Tab(
        'Orígenes',
        Icons.public_outlined,
        Icons.public,
        () => const CatalogScreen(type: CatalogType.origins, embedded: true),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).me;
    if (me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final tabs = _tabs(me);
    if (tabs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Inventario')),
        body: const Center(child: Text('No tienes acceso a este módulo.')),
      );
    }
    final index = _index.clamp(0, tabs.length - 1);

    return Scaffold(
      appBar: AppBar(title: const Text('Inventario')),
      // IndexedStack conserva el estado de cada tab; los no visitados son
      // un placeholder vacío hasta que el usuario los abre.
      body: IndexedStack(
        index: index,
        children: [
          for (var i = 0; i < tabs.length; i++)
            _visited.contains(i) ? tabs[i].build() : const SizedBox.shrink(),
        ],
      ),
      bottomNavigationBar: tabs.length < 2
          ? null
          : NavigationBar(
              selectedIndex: index,
              labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
              onDestinationSelected: (i) => setState(() {
                _index = i;
                _visited.add(i);
              }),
              destinations: [
                for (final t in tabs)
                  NavigationDestination(
                    icon: Icon(t.icon),
                    selectedIcon: Icon(t.selectedIcon),
                    label: t.label,
                  ),
              ],
            ),
    );
  }
}
