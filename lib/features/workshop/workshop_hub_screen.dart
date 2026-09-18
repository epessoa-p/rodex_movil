import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models.dart';
import '../../core/providers.dart';
import '../agenda/agenda_screen.dart';
import 'mechanics_screen.dart';
import 'services_screen.dart';
import 'work_orders_screen.dart';

/// Tabs del hub "Taller". El orden es el de la barra inferior.
enum WorkshopTab { orders, agenda, services, mechanics }

/// Hub "Taller": OTs · Agenda · Servicios · Mecánicos en tabs inferiores (mismo patrón que
/// Compras y Pagos). Cada tab se gatea por su permiso; si queda uno solo se
/// muestra sin barra. Las pantallas se reutilizan en modo `embedded`.
class WorkshopHubScreen extends ConsumerStatefulWidget {
  final WorkshopTab initialTab;
  const WorkshopHubScreen({super.key, this.initialTab = WorkshopTab.orders});

  @override
  ConsumerState<WorkshopHubScreen> createState() => _WorkshopHubScreenState();
}

class _Tab {
  final WorkshopTab key;
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget body;
  const _Tab(this.key, this.label, this.icon, this.selectedIcon, this.body);
}

class _WorkshopHubScreenState extends ConsumerState<WorkshopHubScreen> {
  int? _index; // null hasta resolver el tab inicial con los permisos

  List<_Tab> _tabs(MeContext me) => [
    if (me.can('workshop.view'))
      const _Tab(
        WorkshopTab.orders,
        'OTs',
        Icons.build_circle_outlined,
        Icons.build_circle,
        WorkOrdersScreen(embedded: true),
      ),
    if (me.can('appointments.view'))
      const _Tab(
        WorkshopTab.agenda,
        'Agenda',
        Icons.calendar_month_outlined,
        Icons.calendar_month,
        AgendaScreen(embedded: true),
      ),
    if (me.can('services.view'))
      const _Tab(
        WorkshopTab.services,
        'Servicios',
        Icons.home_repair_service_outlined,
        Icons.home_repair_service,
        ServicesScreen(embedded: true),
      ),
    if (me.can('mechanics.view'))
      const _Tab(
        WorkshopTab.mechanics,
        'Mecánicos',
        Icons.engineering_outlined,
        Icons.engineering,
        MechanicsScreen(embedded: true),
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
        appBar: AppBar(title: const Text('Taller')),
        body: const Center(child: Text('No tienes acceso a este módulo.')),
      );
    }
    // Tab inicial pedido por la ruta (si el usuario lo puede ver).
    final initial = tabs.indexWhere((t) => t.key == widget.initialTab);
    final index = (_index ?? (initial < 0 ? 0 : initial)).clamp(
      0,
      tabs.length - 1,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Taller')),
      body: IndexedStack(
        index: index,
        children: [for (final t in tabs) t.body],
      ),
      // NavigationBar exige al menos 2 destinos.
      bottomNavigationBar: tabs.length < 2
          ? null
          : NavigationBar(
              selectedIndex: index,
              onDestinationSelected: (i) => setState(() => _index = i),
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
