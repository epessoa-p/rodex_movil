import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/select_company_screen.dart';
import '../features/cash/cash_registers_screen.dart';
import '../features/cash/cash_screen.dart';
import '../features/clients/clients_screen.dart';
import '../features/home/home_screen.dart';
import '../features/pos/pos_screen.dart';
import '../features/pos/sales_history_screen.dart';
import '../features/purchases/direct_purchase_screen.dart';
import '../features/purchases/receptions_screen.dart';
import '../features/purchases/suppliers_screen.dart';
import '../features/products/products_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/workshop/work_orders_screen.dart';
import 'providers.dart';

/// Router que redirige según el estado de sesión (auth).
final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier<int>(0);
  ref.listen(authControllerProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/',
    refreshListenable: refresh,
    routes: [
      GoRoute(path: '/', builder: (_, _) => const _Splash()),
      GoRoute(path: '/login', builder: (_, _) => const LoginScreen()),
      GoRoute(
          path: '/select-company',
          builder: (_, _) => const SelectCompanyScreen()),
      GoRoute(path: '/home', builder: (_, _) => const HomeScreen()),
      GoRoute(path: '/pos', builder: (_, _) => const PosScreen()),
      GoRoute(path: '/sales', builder: (_, _) => const SalesHistoryScreen()),
      GoRoute(
          path: '/purchases/receptions',
          builder: (_, _) => const ReceptionsScreen()),
      GoRoute(
          path: '/purchases/suppliers',
          builder: (_, _) => const SuppliersScreen()),
      GoRoute(
          path: '/purchases/direct',
          builder: (_, _) => const DirectPurchaseScreen()),
      GoRoute(path: '/products', builder: (_, _) => const ProductsScreen()),
      GoRoute(path: '/clients', builder: (_, _) => const ClientsScreen()),
      GoRoute(path: '/cash', builder: (_, _) => const CashScreen()),
      GoRoute(
          path: '/cash-registers',
          builder: (_, _) => const CashRegistersScreen()),
      GoRoute(path: '/workshop', builder: (_, _) => const WorkOrdersScreen()),
      GoRoute(path: '/settings', builder: (_, _) => const SettingsScreen()),
    ],
    redirect: (context, state) {
      final status = ref.read(authControllerProvider).status;
      final loc = state.matchedLocation;

      switch (status) {
        case AuthStatus.loading:
          return loc == '/' ? null : '/';
        case AuthStatus.unauthenticated:
          return loc == '/login' ? null : '/login';
        case AuthStatus.needsCompany:
          return loc == '/select-company' ? null : '/select-company';
        case AuthStatus.authenticated:
          if (loc == '/' || loc == '/login' || loc == '/select-company') {
            return '/home';
          }
          return null;
      }
    },
  );
});

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
