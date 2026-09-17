import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/config.dart';
import 'core/providers.dart';
import 'core/router.dart';
import 'core/theme.dart';

void main() {
  runApp(const ProviderScope(child: RodexApp()));
}

class RodexApp extends ConsumerStatefulWidget {
  const RodexApp({super.key});

  @override
  ConsumerState<RodexApp> createState() => _RodexAppState();
}

class _RodexAppState extends ConsumerState<RodexApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Al volver del segundo plano tras un rato, se re-valida la sesión: si el
  /// token venció (inactividad / usuario desactivado) se cae al login ya,
  /// no al primer botón que se toque.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final auth = ref.read(authControllerProvider.notifier);
    if (state == AppLifecycleState.paused) {
      auth.onAppLifecycle(paused: true);
    } else if (state == AppLifecycleState.resumed) {
      auth.onAppLifecycle(paused: false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
