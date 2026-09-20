import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/api_client.dart';
import '../core/token_storage.dart';

final authServiceProvider = Provider<AuthService>(
  (ref) => AuthService(ref.read(apiClientProvider).dio),
);

class AuthService {
  final Dio _dio;

  const AuthService(this._dio);

  /// POST /api/v1/auth/login
  /// Saves the token to storage on success.
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final response = await _dio.post(
      '/auth/login',
      data: {'email': email, 'password': password},
    );

    final data = (response.data as Map<String, dynamic>)['data']
        as Map<String, dynamic>;
    final token = data['token'] as String;

    await TokenStorage.saveToken(token);

    return data;
  }

  /// POST /api/v1/auth/logout
  /// Removes the token from local storage after server invalidation.
  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } finally {
      // Always clear local token even if server call fails
      await TokenStorage.deleteToken();
    }
  }

  /// Checks whether a token is currently stored (user is logged in).
  Future<bool> isLoggedIn() async {
    final token = await TokenStorage.getToken();
    return token != null;
  }
}
