/// App-wide constants for DaanAR.
/// DEV SETUP: Run start-ngrok.ps1 to auto-update baseUrl with the live ngrok tunnel.
/// OR: Set to your local IP (e.g. http://192.168.x.x:8000/api/v1) if on same WiFi.
class AppConstants {
  AppConstants._();

  // Base URL of the Laravel API — direct local IP (same WiFi, no ngrok needed)
  static const String baseUrl = 'http://192.168.0.32:8000/api/v1';

  // Sanctum token storage key
  static const String tokenKey = 'auth_token';

  // Pagination
  static const int defaultPageSize = 15;

  // Landmark categories
  static const List<String> landmarkCategories = [
    'church',
    'park',
    'historical',
    'natural',
    'cultural',
  ];
}
