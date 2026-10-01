/// App-wide constants for DaanAR.
/// DEV SETUP: Run start-ngrok.ps1 to auto-update baseUrl with the live ngrok tunnel.
/// OR: Set to your local IP (e.g. http://192.168.x.x:8000/api/v1) if on same WiFi.
class AppConstants {
  AppConstants._();

  // Base URL of the Laravel API — direct local IP (same WiFi, no ngrok needed)
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

  // ── OpenRouteService (Routing) ───────────────────────────────────────────
  // Sign up free at: https://openrouteservice.org/dev/#/signup
  // Paste your key below (free tier: 2,000 requests/day, no credit card)
  static const String orsApiKey = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjI1YjMyNTA2MWI1NTRiMjE5MTAwZTU3ZDU4MmE4NDA1IiwiaCI6Im11cm11cjY0In0=';
  static const String orsBaseUrl = 'https://api.openrouteservice.org';

  // Navigation thresholds
  static const double arProximityMetres = 50.0;  // trigger AR within 50m
  static const double rerouteThresholdMetres = 30.0; // reroute if > 30m off route
}
