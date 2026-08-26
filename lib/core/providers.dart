import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';
import 'storage.dart';
import '../features/auth/auth_controller.dart';

final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

final secureStoreProvider = Provider<SecureStore>((ref) => SecureStore());

final authControllerProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  return AuthController(
    ref.read(apiClientProvider),
    ref.read(secureStoreProvider),
  )..bootstrap();
});
