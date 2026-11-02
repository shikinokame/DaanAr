import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'constants.dart';
import 'router.dart';
import 'token_storage.dart';

/// Global Dio provider single instance reused across all services.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());

class ApiClient {
  late final Dio _dio;

  ApiClient() {
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConstants.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 15),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          // Skips ngrok's browser warning interstitial page.
          // Without this, ngrok returns HTML instead of JSON,
          // causing DioException and the app falling back to cache.
          'ngrok-skip-browser-warning': 'true',
        },
      ),
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(),
      if (kDebugMode) LogInterceptor(responseBody: true, requestBody: true),
    ]);
  }

  Dio get dio => _dio;
}

/// Injects the stored Sanctum token and mobile number into every request,
/// and kicks the user back to `/register` immediately if the server returns 403 Blocked.
class _AuthInterceptor extends Interceptor {
  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await TokenStorage.getToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    final phone = await TokenStorage.getPhoneNumber();
    if (phone != null && phone.isNotEmpty) {
      options.headers['X-User-Phone'] = phone;
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final path = err.requestOptions.path;
    final isAuthForm = path.contains('/auth/register-mobile') ||
        path.contains('/auth/send-otp') ||
        path.contains('/auth/login');

    if (statusCode == 403 && !isAuthForm) {
      await TokenStorage.deleteToken();
      appRouter.go('/register?blocked=1');
    }

    handler.next(err);
  }
}
