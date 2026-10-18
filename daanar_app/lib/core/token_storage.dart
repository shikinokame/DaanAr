import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

/// Persists authentication token and registered mobile user session
/// (`userId`, `phoneNumber`, `userRole`) in SharedPreferences.
class TokenStorage {
  TokenStorage._();

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.tokenKey);
  }

  static Future<void> saveUserSession({
    required int userId,
    required String phoneNumber,
    required String userRole,
    String? token,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(AppConstants.userIdKey, userId);
    await prefs.setString(AppConstants.phoneNumberKey, phoneNumber);
    await prefs.setString(AppConstants.userRoleKey, userRole);
    if (token != null) {
      await prefs.setString(AppConstants.tokenKey, token);
    }
  }

  static Future<int?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(AppConstants.userIdKey);
  }

  static Future<String?> getPhoneNumber() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.phoneNumberKey);
  }

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(AppConstants.userRoleKey);
  }

  static Future<bool> hasMobileRegistration() async {
    final prefs = await SharedPreferences.getInstance();
    final phone = prefs.getString(AppConstants.phoneNumberKey);
    final role = prefs.getString(AppConstants.userRoleKey);
    return phone != null && phone.isNotEmpty && role != null && role.isNotEmpty;
  }

  static Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userIdKey);
    await prefs.remove(AppConstants.phoneNumberKey);
    await prefs.remove(AppConstants.userRoleKey);
  }
}
