import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists API responses locally so the app works when the server is offline.
/// Uses SharedPreferences (key-value store) to save JSON strings.
class CacheService {
  static const _prefix = 'daanar_cache_';

  /// Saves a list of JSON-encodable maps under [key].
  static Future<void> saveList(
    String key,
    List<Map<String, dynamic>> data,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefix + key, jsonEncode(data));
  }

  /// Loads a cached list. Returns null if nothing is cached or cache is corrupted.
  static Future<List<Map<String, dynamic>>?> loadList(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefix + key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        // Corrupted / unexpected format purge it
        await prefs.remove(_prefix + key);
        return null;
      }
      return decoded.cast<Map<String, dynamic>>();
    } catch (_) {
      // Not valid JSON (e.g. HTML error page accidentally saved)
      await prefs.remove(_prefix + key);
      return null;
    }
  }

  /// Saves a single JSON-encodable map under [key].
  static Future<void> saveMap(String key, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefix + key, jsonEncode(data));
  }

  /// Loads a single cached map. Returns null if nothing is cached or cache is corrupted.
  static Future<Map<String, dynamic>?> loadMap(String key) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefix + key);
    if (raw == null) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        await prefs.remove(_prefix + key);
        return null;
      }
      return decoded;
    } catch (_) {
      await prefs.remove(_prefix + key);
      return null;
    }
  }

  /// Removes a specific cache entry.
  static Future<void> clear(String key) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefix + key);
  }

  /// Removes ALL cached data for DaanAR.
  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((k) => k.startsWith(_prefix)).toList();
    for (final key in keys) {
      await prefs.remove(key);
    }
  }

  // Cache keys
  static const String keyLandmarks = 'landmarks';
  static const String keyLandmarkListMeta = 'landmarks_meta';
  static const String keyLandmarkCatalog = 'landmark_catalog';
  static const String keyFeaturedLandmarks = 'landmarks_featured';
  static const String keyMunicipalities = 'municipalities';
  static const String keyTrails = 'trails';

  /// Reads the complete catalog, with support for page-one caches from older builds.
  static Future<({List<Map<String, dynamic>> records, int? total})?>
  loadLandmarkCatalog() async {
    final snapshot = await loadMap(keyLandmarkCatalog);
    final records = snapshot?['records'];
    if (records is List &&
        records.every((record) => record is Map<String, dynamic>)) {
      return (
        records: records.cast<Map<String, dynamic>>(),
        total: (snapshot?['total'] as num?)?.toInt(),
      );
    }

    final legacyRecords = await loadList(keyLandmarks);
    if (legacyRecords == null) return null;
    final legacyMeta = await loadMap(keyLandmarkListMeta);
    return (
      records: legacyRecords,
      total: (legacyMeta?['total'] as num?)?.toInt(),
    );
  }

  /// Returns the key used to cache a single landmark detail.
  static String landmarkDetailKey(int id) => 'landmark_$id';

  /// Returns the key used to cache a single trail detail.
  static String trailDetailKey(int id) => 'trail_$id';
}
