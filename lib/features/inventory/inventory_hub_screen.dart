import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/hub_nav_bar.dart';
import '../../core/models.dart';
import '../../core/module_colors.dart';
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

class _InventoryHubScreenState extends ConsumerState<InventoryHubScreen> {
  int _index = 0;
  final _visited = <int>{0};

  List<HubTab> _tabs(MeContext me) => [
    if (me.canAny(['products.view', 'pos.access', 'sales.view']))
      HubTab(
        label: 'Productos',
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
        color: ModuleColors.products,
        build: () => const ProductsScreen(embedded: true),
      ),
    if (me.can('product-categories.view'))
      HubTab(
        label: 'Categorías',
        icon: Icons.category_outlined,
        selectedIcon: Icons.category,
        color: ModuleColors.categories,
        build: () =>
            const CatalogScreen(type: CatalogType.categories, embedded: true),
      ),
    if (me.can('product-brands.view'))
      HubTab(
        label: 'Marcas',
        icon: Icons.sell_outlined,
        selectedIcon: Icons.sell,
        color: ModuleColors.brands,
        build: () =>
            const CatalogScreen(type: CatalogType.brands, embedded: true),
      ),
    if (me.can('moto-models.view'))
      HubTab(
        label: 'Modelos',
        icon: Icons.two_wheeler_outlined,
        selectedIcon: Icons.two_wheeler,
        color: ModuleColors.models,
        build: () =>
            const CatalogScreen(type: CatalogType.motoModels, embedded: true),
      ),
    if (me.can('product-origins.view'))
      HubTab(
        label: 'Orígenes',
        icon: Icons.public_outlined,
        selectedIcon: Icons.public,
        color: ModuleColors.origins,
        build: () =>
            const CatalogScreen(type: CatalogType.origins, embedded: true),
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
          : HubNavBar(
              tabs: tabs,
              selectedIndex: index,
              onSelected: (i) => setState(() {
                _index = i;
                _visited.add(i);
              }),
            ),
    );
  }
}
