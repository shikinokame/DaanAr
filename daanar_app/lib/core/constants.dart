/// App-wide constants for DaanAR.
/// ngrok HTTPS tunnel — required for WebView camera access (getUserMedia needs HTTPS).
/// Run: C:\ngrok\ngrok.exe http 192.168.0.27:8000
/// Update this URL each time ngrok restarts (free tier gives a new URL each time).
class AppConstants {
  AppConstants._();

  // Base URL of the Laravel API (via ngrok HTTPS tunnel)
  static const String baseUrl = 'https://letdown-twiddle-thirty.ngrok-free.dev/api/v1';

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
