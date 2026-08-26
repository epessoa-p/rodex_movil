import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'core/theme.dart';

void main() {
  runApp(const ProviderScope(child: RodexApp()));
}

class RodexApp extends ConsumerWidget {
  const RodexApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    // Si la empresa definió color, tinta el tema (white-label).
    final me = ref.watch(authControllerProvider).me;
    final seed = AppTheme.colorFromHex(me?.company?.themePrimary);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(seed),
      routerConfig: router,
    );
  }
}
