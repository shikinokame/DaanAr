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

  /// Normalize Philippine phone number to `+639XXXXXXXXX`.
  static String normalizePhilippinePhone(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D+'), '');
    if (digits.startsWith('09') && digits.length == 11) {
      return '+63${digits.substring(1)}';
    }
    if (digits.startsWith('9') && digits.length == 10) {
      return '+63$digits';
    }
    if (digits.startsWith('639') && digits.length == 12) {
      return '+$digits';
    }
    return '+${raw.replaceAll(RegExp(r'^\++'), '')}';
  }

  /// Validates whether [raw] is a valid Philippine mobile number (`09XXXXXXXXX` or `+639XXXXXXXXX`).
  static bool isValidPhilippinePhone(String raw) {
    final normalized = normalizePhilippinePhone(raw);
    return RegExp(r'^\+639\d{9}$').hasMatch(normalized);
  }

  /// POST /api/v1/auth/register-mobile
  /// Registers or retrieves the user by mobile number + role and persists
  /// `userId`, `phoneNumber`, `userRole`, and `token` locally.
  Future<Map<String, dynamic>> registerMobile({
    required String phoneNumber,
    required String userRole,
  }) async {
    final normalizedPhone = normalizePhilippinePhone(phoneNumber);

    try {
      final response = await _dio.post(
        '/auth/register-mobile',
        data: {
          'phone_number': normalizedPhone,
          'user_role': userRole,
        },
      );

      final body = response.data as Map<String, dynamic>;
      final data = (body['data'] as Map<String, dynamic>?) ?? body;
      final userMap = (data['user'] as Map<String, dynamic>?) ?? data;

      final userId = (data['user_id'] ?? userMap['id'] ?? userMap['user_id']) as int;
      final token = data['token'] as String?;

      await TokenStorage.saveUserSession(
        userId: userId,
        phoneNumber: normalizedPhone,
        userRole: userRole,
        token: token,
      );

      return data;
    } on DioException catch (e) {
      // If user account is explicitly blocked (403), rethrow to show message
      if (e.response?.statusCode == 403 || e.response?.statusCode == 422) {
        rethrow;
      }

      // Offline / legacy backend fallback: derive a deterministic positive userId
      // from the phone number so analytics events still carry a consistent userId
      // and sync once the backend is reachable.
      final fallbackUserId =
          normalizedPhone.hashCode.abs() % 900000 + 100000;
      await TokenStorage.saveUserSession(
        userId: fallbackUserId,
        phoneNumber: normalizedPhone,
        userRole: userRole,
      );
      return {
        'user_id': fallbackUserId,
        'phone_number': normalizedPhone,
        'user_role': userRole,
        'offline_fallback': true,
      };
    }
  }

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

  /// Checks whether a user session or token is currently stored.
  Future<bool> isLoggedIn() async {
    if (await TokenStorage.hasMobileRegistration()) return true;
    final token = await TokenStorage.getToken();
    return token != null;
  }
}
