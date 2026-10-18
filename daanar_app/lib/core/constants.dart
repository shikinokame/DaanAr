/// App-wide constants for DaanAR.
/// DEV SETUP: Run start-ngrok.ps1 to auto-update baseUrl with the live ngrok tunnel.
/// OR: Set to your local IP (e.g. http://192.168.x.x:8000/api/v1) if on same WiFi.
class AppConstants {
  AppConstants._();

  // ── API Base URL ─────────────────────────────────────────────────────────
  // DEVELOPMENT: Use ngrok or your local IP.
  // PRODUCTION:  Change to your Railway domain before running `flutter build apk --release`
  //
  // Current mode → PRODUCTION (Railway)
  static const String baseUrl = 'https://daanar-production.up.railway.app/api/v1';

  // DEVELOPMENT URL (ngrok):
  // static const String baseUrl = 'https://letdown-twiddle-thirty.ngrok-free.dev/api/v1';

  // Sanctum token & mobile user storage keys
  static const String tokenKey = 'auth_token';
  static const String userIdKey = 'auth_user_id';
  static const String phoneNumberKey = 'auth_phone_number';
  static const String userRoleKey = 'auth_user_role';

  // Available mobile visitor roles
  static const List<String> userRoles = [
    'Tourist',
    'Student',
    'Educator',
  ];

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

  // Navigation & Geofence thresholds
  static const double physicalVisitRadiusMetres = 100.0; // On-site geofence radius (100m)
  static const double arProximityMetres = 50.0;          // trigger AR prompt within 50m
  static const double rerouteThresholdMetres = 30.0;     // reroute if > 30m off route
}
