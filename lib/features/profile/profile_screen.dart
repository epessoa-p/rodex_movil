import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/api_client.dart';
import '../../core/config.dart';
import '../../core/models.dart';
import '../../core/providers.dart';

/// Perfil / cuenta: datos del usuario, empresa activa (y cambio de empresa),
/// cambio de contraseña, cerrar sesión y versión de la app.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(authControllerProvider).me;

    return Scaffold(
      appBar: AppBar(title: const Text('Perfil')),
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

                // ── Seguridad ──
                const _SectionTitle('Seguridad'),
                ListTile(
                  leading: const Icon(Icons.lock_outline),
                  title: const Text('Cambiar contraseña'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _changePassword(context, ref),
                ),
                const Divider(height: 1),

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

  Future<void> _changePassword(BuildContext context, WidgetRef ref) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => const _ChangePasswordDialog(),
    );
    if (ok == true && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Contraseña actualizada.')),
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

/// Diálogo de cambio de contraseña: actual + nueva + confirmación.
class _ChangePasswordDialog extends ConsumerStatefulWidget {
  const _ChangePasswordDialog();

  @override
  ConsumerState<_ChangePasswordDialog> createState() =>
      _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends ConsumerState<_ChangePasswordDialog> {
  final _current = TextEditingController();
  final _nueva = TextEditingController();
  final _confirma = TextEditingController();
  bool _saving = false;
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    for (final c in [_current, _nueva, _confirma]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    final current = _current.text;
    final nueva = _nueva.text;

    if (current.isEmpty) {
      setState(() => _error = 'Ingresa tu contraseña actual.');
      return;
    }
    if (nueva.length < 8) {
      setState(() => _error = 'La nueva contraseña debe tener al menos 8 caracteres.');
      return;
    }
    if (nueva != _confirma.text) {
      setState(() => _error = 'La confirmación no coincide con la nueva contraseña.');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(authControllerProvider.notifier)
          .changePassword(current, nueva);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar contraseña'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _field(_current, 'Contraseña actual'),
            const SizedBox(height: 12),
            _field(_nueva, 'Nueva contraseña',
                helper: 'Mínimo 8 caracteres'),
            const SizedBox(height: 12),
            _field(_confirma, 'Confirmar nueva contraseña'),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 8),
            Text(
              'Al cambiarla se cerrarán tus otras sesiones.',
              style: TextStyle(
                  color: Theme.of(context).colorScheme.outline, fontSize: 12),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child:
                      CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Guardar'),
        ),
      ],
    );
  }

  Widget _field(TextEditingController c, String label, {String? helper}) {
    return TextField(
      controller: c,
      obscureText: _obscure,
      decoration: InputDecoration(
        labelText: label,
        helperText: helper,
        border: const OutlineInputBorder(),
        isDense: true,
        suffixIcon: IconButton(
          icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility,
              size: 20),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
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
                if (user.phone != null && user.phone!.isNotEmpty)
                  Row(
                    children: [
                      const Icon(Icons.phone_outlined,
                          size: 14, color: Colors.black45),
                      const SizedBox(width: 4),
                      Text(user.phone!,
                          style: const TextStyle(color: Colors.black54)),
                    ],
                  ),
                if (company != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(company!.name,
                        style: const TextStyle(
                            color: Colors.black45, fontSize: 13)),
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
