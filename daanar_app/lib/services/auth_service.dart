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

  /// POST /api/v1/auth/send-otp
  /// Requests a 6-digit verification code for [phoneNumber].
  /// If the server is unreachable (offline mode), generates a local 6-digit simulator code
  /// so the OTP verification flow still works seamlessly during offline testing.
  Future<Map<String, dynamic>> sendOtp({
    required String phoneNumber,
  }) async {
    final normalizedPhone = normalizePhilippinePhone(phoneNumber);

    try {
      final response = await _dio.post(
        '/auth/send-otp',
        data: {
          'phone_number': normalizedPhone,
        },
      );

      final body = response.data as Map<String, dynamic>;
      final data = (body['data'] as Map<String, dynamic>?) ?? body;
      return data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403 || e.response?.statusCode == 422) {
        rethrow;
      }

      // Offline fallback: generate local 6-digit code
      final localCode =
          ((DateTime.now().millisecondsSinceEpoch % 900000) + 100000).toString();
      return {
        'phone_number': normalizedPhone,
        'masked_phone': normalizedPhone,
        'expires_in': 300,
        'delivery_channel': 'simulator',
        'otp_token': 'offline.$localCode',
        'demo_otp': localCode,
      };
    }
  }

  /// POST /api/v1/auth/register-mobile
  /// Verifies the 6-digit OTP and registers or retrieves the user by mobile number,
  /// persisting `userId`, `phoneNumber`, `userRole`, and `token` locally.
  Future<Map<String, dynamic>> registerMobile({
    required String phoneNumber,
    required String userRole,
    String? otpCode,
    String? otpToken,
  }) async {
    final normalizedPhone = normalizePhilippinePhone(phoneNumber);

    // Verify offline OTP token if generated while offline
    if (otpToken != null && otpToken.startsWith('offline.')) {
      final expectedCode = otpToken.substring('offline.'.length);
      if (otpCode != expectedCode) {
        throw DioException(
          requestOptions: RequestOptions(path: '/auth/register-mobile'),
          response: Response(
            requestOptions: RequestOptions(path: '/auth/register-mobile'),
            statusCode: 422,
            data: {
              'message':
                  'The 6-digit verification code is invalid or has expired.',
            },
          ),
          type: DioExceptionType.badResponse,
        );
      }
    }

    try {
      final response = await _dio.post(
        '/auth/register-mobile',
        data: {
          'phone_number': normalizedPhone,
          'user_role': userRole,
          'otp_code': ?otpCode,
          'otp_token': ?otpToken,
        },
      );

      final body = response.data as Map<String, dynamic>;
      final data = (body['data'] as Map<String, dynamic>?) ?? body;
      final userMap = (data['user'] as Map<String, dynamic>?) ?? data;

      final userId =
          (data['user_id'] ?? userMap['id'] ?? userMap['user_id']) as int;
      final token = data['token'] as String?;

      await TokenStorage.saveUserSession(
        userId: userId,
        phoneNumber: normalizedPhone,
        userRole: userRole,
        token: token,
      );

      return data;
    } on DioException catch (e) {
      // If user account is explicitly blocked (403) or OTP invalid (422), rethrow to show message
      if (e.response?.statusCode == 403 || e.response?.statusCode == 422) {
        rethrow;
      }

      // Offline / legacy backend fallback: derive a deterministic positive userId
      // from the phone number so analytics events still carry a consistent userId
      // and sync once the backend is reachable.
      final fallbackUserId = normalizedPhone.hashCode.abs() % 900000 + 100000;
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

  /// GET /api/v1/auth/me
  /// Verifies with the server on app launch whether the registered mobile user
  /// is still `Active` (`'active'`), `Blocked` (`'blocked'`), or deleted (`'unregistered'`).
  /// If offline / unreachable, returns `'offline'` so cached exploration continues to work.
  Future<String> verifyActiveSession() async {
    final phone = await TokenStorage.getPhoneNumber();
    final userId = await TokenStorage.getUserId();

    if (phone == null || phone.isEmpty) {
      return 'unregistered';
    }

    try {
      await _dio.get(
        '/auth/me',
        queryParameters: {
          'phone_number': phone,
          'user_id': ?userId,
        },
        options: Options(
          sendTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      return 'active';
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 403) {
        await TokenStorage.deleteToken();
        return 'blocked';
      }
      if (code == 401) {
        await TokenStorage.deleteToken();
        return 'unregistered';
      }
      // Network timeout / offline — keep local session intact for offline browsing
      return 'offline';
    } catch (_) {
      return 'offline';
    }
  }
}
