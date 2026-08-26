import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/providers.dart';

class SelectCompanyScreen extends ConsumerWidget {
  const SelectCompanyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final companies = auth.companies;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Elige tu empresa'),
        actions: [
          TextButton(
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
            child: const Text('Salir',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: companies.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final c = companies[i];
          return Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.store_outlined)),
              title: Text(c.name,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () =>
                  ref.read(authControllerProvider.notifier).selectCompany(c.id),
            ),
          );
        },
      ),
    );
  }
}
