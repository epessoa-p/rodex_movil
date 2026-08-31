import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/api_client.dart';
import '../../core/providers.dart';
import 'company_profile_repository.dart';

/// "Mi empresa": la empresa activa edita teléfono, dirección, foto y la
/// vigencia del enlace de seguimiento.
class CompanyProfileScreen extends ConsumerWidget {
  const CompanyProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(companyProfileProvider);
    final me = ref.watch(authControllerProvider).me;
    final canEdit = me?.can('company-profile.edit') ?? false;

    return Scaffold(
      appBar: AppBar(title: const Text('Mi empresa')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e', textAlign: TextAlign.center)),
        data: (c) => _Form(profile: c, canEdit: canEdit),
      ),
    );
  }
}

class _Form extends ConsumerStatefulWidget {
  final CompanyProfile profile;
  final bool canEdit;
  const _Form({required this.profile, required this.canEdit});

  @override
  ConsumerState<_Form> createState() => _FormState();
}

class _FormState extends ConsumerState<_Form> {
  late final _phone = TextEditingController(text: widget.profile.phone ?? '');
  late final _address =
      TextEditingController(text: widget.profile.address ?? '');
  late final _days = TextEditingController(
      text: widget.profile.trackingLinkDays.toString());
  late final List<String> _order = _initOrder(widget.profile.dashboardOrder);
  String? _newLogoPath;
  bool _saving = false;

  static const _labels = {
    'ventas': 'Ventas',
    'taller': 'Taller',
    'compras': 'Compras',
  };

  static List<String> _initOrder(String csv) {
    final valid = ['ventas', 'taller', 'compras'];
    final out = <String>[];
    for (final m in csv.split(',')) {
      final k = m.trim();
      if (valid.contains(k) && !out.contains(k)) out.add(k);
    }
    for (final k in valid) {
      if (!out.contains(k)) out.add(k);
    }
    return out;
  }

  final _picker = ImagePicker();

  @override
  void dispose() {
    _phone.dispose();
    _address.dispose();
    _days.dispose();
    super.dispose();
  }

  Future<void> _pickLogo() async {
    try {
      final f = await _picker.pickImage(
          source: ImageSource.gallery, imageQuality: 85, maxWidth: 800);
      if (f != null) setState(() => _newLogoPath = f.path);
    } catch (e) {
      _snack('No se pudo elegir la imagen: $e');
    }
  }

  Future<void> _save() async {
    final days = int.tryParse(_days.text.trim());
    if (days == null || days < 0 || days > 365) {
      _snack('La vigencia debe ser un número entre 0 y 365.');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(companyProfileRepositoryProvider).update(
            phone: _phone.text.trim().isEmpty ? null : _phone.text.trim(),
            address: _address.text.trim().isEmpty ? null : _address.text.trim(),
            trackingLinkDays: days,
            dashboardOrder: _order.join(','),
            logoPath: _newLogoPath,
          );
      ref.invalidate(companyProfileProvider);
      // Recarga `me` para que el dashboard tome el nuevo orden/logo.
      await ref.read(authControllerProvider.notifier).refreshMe();
      if (mounted) {
        setState(() => _saving = false);
        _snack('Datos de tu empresa actualizados.');
      }
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(e.message);
      }
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final c = widget.profile;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: Column(
            children: [
              Text(c.name,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w700)),
              const SizedBox(height: 12),
              CircleAvatar(
                radius: 54,
                backgroundColor: Colors.grey.withValues(alpha: .15),
                backgroundImage: _newLogoPath != null
                    ? FileImage(File(_newLogoPath!))
                    : (c.logoUrl != null && c.logoUrl!.isNotEmpty
                            ? NetworkImage(c.logoUrl!)
                            : null)
                        as ImageProvider?,
                child: (_newLogoPath == null &&
                        (c.logoUrl == null || c.logoUrl!.isEmpty))
                    ? const Icon(Icons.storefront_outlined, size: 40)
                    : null,
              ),
              if (widget.canEdit)
                TextButton.icon(
                  onPressed: _pickLogo,
                  icon: const Icon(Icons.photo_camera_outlined, size: 18),
                  label: const Text('Cambiar foto'),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _phone,
          enabled: widget.canEdit,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(
              labelText: 'Teléfono', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _address,
          enabled: widget.canEdit,
          minLines: 2,
          maxLines: 3,
          decoration: const InputDecoration(
              labelText: 'Dirección', border: OutlineInputBorder()),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _days,
          enabled: widget.canEdit,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            labelText: 'Vigencia del enlace de seguimiento (días)',
            helperText:
                'Días que el enlace sigue activo después de entregar la OT. 0 = sin caducidad.',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 20),
        const Text('Orden de los tabs del dashboard',
            style: TextStyle(fontWeight: FontWeight.w700)),
        const Text('Arrastra para ordenar. El primero se muestra primero.',
            style: TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(height: 6),
        ReorderableListView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          buildDefaultDragHandles: widget.canEdit,
          onReorder: (oldI, newI) {
            if (!widget.canEdit) return;
            setState(() {
              if (newI > oldI) newI -= 1;
              final item = _order.removeAt(oldI);
              _order.insert(newI, item);
            });
          },
          children: [
            for (final m in _order)
              Card(
                key: ValueKey(m),
                margin: const EdgeInsets.symmetric(vertical: 3),
                child: ListTile(
                  leading: const Icon(Icons.drag_indicator),
                  title: Text(_labels[m] ?? m),
                ),
              ),
          ],
        ),
        const SizedBox(height: 20),
        if (widget.canEdit)
          FilledButton.icon(
            style:
                FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.check),
            label: const Text('Guardar cambios'),
            onPressed: _saving ? null : _save,
          ),
      ],
    );
  }
}
