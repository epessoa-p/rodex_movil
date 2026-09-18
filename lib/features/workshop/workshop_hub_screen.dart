import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/hub_nav_bar.dart';
import '../../core/models.dart';
import '../../core/module_colors.dart';
import '../../core/providers.dart';
import '../agenda/agenda_screen.dart';
import 'mechanics_screen.dart';
import 'services_screen.dart';
import 'work_orders_screen.dart';

/// Tabs del hub "Taller". El orden es el de la barra inferior.
enum WorkshopTab { orders, agenda, services, mechanics }

/// Hub "Taller": OTs · Agenda · Servicios · Mecánicos en tabs inferiores, cada
/// uno con su color (mismo patrón que Compras, Pagos e Inventario). Cada tab
/// se gatea por su permiso; si queda uno solo se muestra sin barra. Las
/// pantallas se reutilizan en modo `embedded`.
class WorkshopHubScreen extends ConsumerStatefulWidget {
  final WorkshopTab initialTab;
  const WorkshopHubScreen({super.key, this.initialTab = WorkshopTab.orders});

  @override
  ConsumerState<WorkshopHubScreen> createState() => _WorkshopHubScreenState();
}

class _WorkshopHubScreenState extends ConsumerState<WorkshopHubScreen> {
  int? _index; // null hasta resolver el tab inicial con los permisos

  List<(WorkshopTab, HubTab)> _tabs(MeContext me) => [
    if (me.can('workshop.view'))
      (
        WorkshopTab.orders,
        HubTab(
          label: 'OTs',
          icon: Icons.build_circle_outlined,
          selectedIcon: Icons.build_circle,
          color: ModuleColors.workOrders,
          build: () => const WorkOrdersScreen(embedded: true),
        ),
      ),
    if (me.can('appointments.view'))
      (
        WorkshopTab.agenda,
        HubTab(
          label: 'Agenda',
          icon: Icons.calendar_month_outlined,
          selectedIcon: Icons.calendar_month,
          color: ModuleColors.agenda,
          build: () => const AgendaScreen(embedded: true),
        ),
      ),
    if (me.can('services.view'))
      (
        WorkshopTab.services,
        HubTab(
          label: 'Servicios',
          icon: Icons.home_repair_service_outlined,
          selectedIcon: Icons.home_repair_service,
          color: ModuleColors.services,
          build: () => const ServicesScreen(embedded: true),
        ),
      ),
    if (me.can('mechanics.view'))
      (
        WorkshopTab.mechanics,
        HubTab(
          label: 'Mecánicos',
          icon: Icons.engineering_outlined,
          selectedIcon: Icons.engineering,
          color: ModuleColors.mechanics,
          build: () => const MechanicsScreen(embedded: true),
        ),
      ),
  ];

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(authControllerProvider).me;
    if (me == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final entries = _tabs(me);
    if (entries.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Taller')),
        body: const Center(child: Text('No tienes acceso a este módulo.')),
      );
    }
    final tabs = [for (final e in entries) e.$2];
    // Tab inicial pedido por la ruta (si el usuario lo puede ver).
    final initial = entries.indexWhere((e) => e.$1 == widget.initialTab);
    final index = (_index ?? (initial < 0 ? 0 : initial)).clamp(
      0,
      tabs.length - 1,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Taller')),
      body: IndexedStack(
        index: index,
        children: [for (final t in tabs) t.build()],
      ),
      // NavigationBar exige al menos 2 destinos.
      bottomNavigationBar: tabs.length < 2
          ? null
          : HubNavBar(
              tabs: tabs,
              selectedIndex: index,
              onSelected: (i) => setState(() => _index = i),
            ),
    );
  }
}
