import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/config.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

/// Ajustes / Perfil: datos del usuario y empresa, cambiar de empresa, cerrar
/// sesión y versión de la app.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider).me;

    return Scaffold(
      appBar: AppBar(title: const Text('Ajustes')),
      body: me == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                _UserHeader(user: me.user, company: me.company),
                const Divider(height: 1),

                // ── Empresa activa / cambiar empresa ──
                if (me.companies.length > 1) ...[
                  const _SectionTitle('Cambiar de empresa'),
                  for (final c in me.companies)
                    ListTile(
                      leading: const Icon(Icons.storefront_outlined),
                      title: Text(c.name),
                      trailing: c.id == me.company?.id
                          ? Icon(Icons.check_circle,
                              color: Theme.of(context).colorScheme.primary)
                          : null,
                      onTap: () => _switchCompany(context, ref, c),
                    ),
                  const Divider(height: 1),
                ] else if (me.company != null) ...[
                  ListTile(
                    leading: const Icon(Icons.storefront_outlined),
                    title: const Text('Empresa'),
                    subtitle: Text(me.company!.name),
                  ),
                  const Divider(height: 1),
                ],

                // ── Administración ──
                if (me.planAllows('cash') && me.can('cash-registers.view')) ...[
                  const _SectionTitle('Administración'),
                  ListTile(
                    leading: const Icon(Icons.point_of_sale_outlined),
                    title: const Text('Cajas'),
                    subtitle: const Text('Crear y asignar cajas al personal'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/cash-registers'),
                  ),
                  const Divider(height: 1),
                ],

                // ── Cerrar sesión ──
                ListTile(
                  leading: const Icon(Icons.logout, color: Colors.red),
                  title: const Text('Cerrar sesión',
                      style: TextStyle(color: Colors.red)),
                  onTap: () => _confirmLogout(context, ref),
                ),
                const Divider(height: 1),

                const SizedBox(height: 24),
                Center(
                  child: Text(
                    '${AppConfig.appName} · v${AppConfig.appVersion}',
                    style: const TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Future<void> _switchCompany(
      BuildContext context, WidgetRef ref, Company c) async {
    if (ref.read(authControllerProvider).me?.company?.id == c.id) return;
    // Cambia de empresa (recarga /me: moneda, tema, permisos) y vuelve al inicio.
    await ref.read(authControllerProvider.notifier).selectCompany(c.id);
    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Empresa activa: ${c.name}')),
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar sesión'),
        content: const Text('¿Seguro que quieres salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Salir'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(authControllerProvider.notifier).logout();
      // El router redirige a /login por el cambio de estado de sesión.
    }
  }
}

class _UserHeader extends StatelessWidget {
  final AppUser user;
  final Company? company;
  const _UserHeader({required this.user, required this.company});

  @override
  Widget build(BuildContext context) {
    final initial = user.name.isNotEmpty ? user.name[0].toUpperCase() : '?';
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          CircleAvatar(
            radius: 28,
            child: Text(initial, style: const TextStyle(fontSize: 22)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w700)),
                if (user.email != null && user.email!.isNotEmpty)
                  Text(user.email!,
                      style: const TextStyle(color: Colors.black54)),
                if (company != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(company!.name,
                        style: const TextStyle(color: Colors.black45, fontSize: 13)),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(text,
          style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w700,
              fontSize: 13)),
    );
  }
}
