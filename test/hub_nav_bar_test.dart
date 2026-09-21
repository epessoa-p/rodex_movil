import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rodex_movil/core/hub_nav_bar.dart';
import 'package:rodex_movil/core/module_colors.dart';

void main() {
  testWidgets('HubNavBar: 5 tabs a 360 dp, cada uno con su color', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final tabs = [
      HubTab(
        label: 'Productos',
        icon: Icons.inventory_2_outlined,
        selectedIcon: Icons.inventory_2,
        color: ModuleColors.products,
        build: () => const SizedBox(),
      ),
      HubTab(
        label: 'Categorías',
        icon: Icons.category_outlined,
        selectedIcon: Icons.category,
        color: ModuleColors.categories,
        build: () => const SizedBox(),
      ),
      HubTab(
        label: 'Marcas',
        icon: Icons.sell_outlined,
        selectedIcon: Icons.sell,
        color: ModuleColors.brands,
        build: () => const SizedBox(),
      ),
      HubTab(
        label: 'Modelos',
        icon: Icons.two_wheeler_outlined,
        selectedIcon: Icons.two_wheeler,
        color: ModuleColors.models,
        build: () => const SizedBox(),
      ),
      HubTab(
        label: 'Orígenes',
        icon: Icons.public_outlined,
        selectedIcon: Icons.public,
        color: ModuleColors.origins,
        build: () => const SizedBox(),
      ),
    ];

    var selected = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: StatefulBuilder(
          builder: (context, setState) => Scaffold(
            appBar: AppBar(title: const Text('Inventario')),
            body: const SizedBox(),
            bottomNavigationBar: HubNavBar(
              tabs: tabs,
              selectedIndex: selected,
              onSelected: (i) => setState(() => selected = i),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    // Indicador y franja (encima de la barra) con el color del tab activo.
    NavigationBarThemeData theme() =>
        tester.widget<NavigationBarTheme>(find.byType(NavigationBarTheme)).data;
    expect(theme().indicatorColor, ModuleColors.soft(ModuleColors.products));
    expect(
      tester.widget<HubAccentBar>(find.byType(HubAccentBar)).color,
      ModuleColors.products,
    );

    // Cada ícono no activo va en su propio color (atenuado).
    final catIcon = tester.widget<Icon>(find.byIcon(Icons.category_outlined));
    expect(catIcon.color, ModuleColors.categories.withValues(alpha: .75));

    // Al tocar Orígenes cambian indicador, etiqueta y franja a su color.
    await tester.tap(find.text('Orígenes'));
    await tester.pumpAndSettle();
    expect(theme().indicatorColor, ModuleColors.soft(ModuleColors.origins));
    expect(
      tester.widget<HubAccentBar>(find.byType(HubAccentBar)).color,
      ModuleColors.origins,
    );
    expect(tester.takeException(), isNull);
  });
}
