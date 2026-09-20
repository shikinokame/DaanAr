import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';

/// Simple token persistence using shared_preferences.
/// Swap for flutter_secure_storage in production for better security.
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

  static Future<void> deleteToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
  }
}
