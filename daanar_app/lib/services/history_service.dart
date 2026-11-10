import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/cache_service.dart';
import '../models/landmark.dart';

enum HistoryEntryType {
  visit,
  ar;

  String get toJsonValue => name;

  static HistoryEntryType fromJsonValue(String? raw) {
    if (raw == 'ar') return HistoryEntryType.ar;
    return HistoryEntryType.visit;
  }
}

class HistoryEntry {
  final String id;
  final int landmarkId;
  final String landmarkName;
  final String municipalityName;
  final String? heroImageUrl;
  final String category;
  final HistoryEntryType type;
  final String subtitle;
  final DateTime timestamp;

  const HistoryEntry({
    required this.id,
    required this.landmarkId,
    required this.landmarkName,
    required this.municipalityName,
    this.heroImageUrl,
    required this.category,
    required this.type,
    required this.subtitle,
    required this.timestamp,
  });

  HistoryEntry copyWith({
    String? id,
    int? landmarkId,
    String? landmarkName,
    String? municipalityName,
    String? heroImageUrl,
    String? category,
    HistoryEntryType? type,
    String? subtitle,
    DateTime? timestamp,
  }) {
    return HistoryEntry(
      id: id ?? this.id,
      landmarkId: landmarkId ?? this.landmarkId,
      landmarkName: landmarkName ?? this.landmarkName,
      municipalityName: municipalityName ?? this.municipalityName,
      heroImageUrl: heroImageUrl ?? this.heroImageUrl,
      category: category ?? this.category,
      type: type ?? this.type,
      subtitle: subtitle ?? this.subtitle,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'landmark_id': landmarkId,
        'landmark_name': landmarkName,
        'municipality_name': municipalityName,
        'hero_image_url': heroImageUrl,
        'category': category,
        'type': type.toJsonValue,
        'subtitle': subtitle,
        'timestamp': timestamp.toIso8601String(),
      };

  factory HistoryEntry.fromJson(Map<String, dynamic> json) {
    return HistoryEntry(
      id: json['id'] as String? ??
          '${json['landmark_id']}_${json['type']}_${json['timestamp']}',
      landmarkId: (json['landmark_id'] as num?)?.toInt() ?? 0,
      landmarkName: json['landmark_name'] as String? ?? 'Heritage Landmark',
      municipalityName: json['municipality_name'] as String? ?? 'Pangasinan',
      heroImageUrl: json['hero_image_url'] as String?,
      category: json['category'] as String? ?? 'historical',
      type: HistoryEntryType.fromJsonValue(json['type'] as String?),
      subtitle: json['subtitle'] as String? ?? 'On-site visit · Verified GPS',
      timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// Manages local persistence and live updates for User Visit & AR Viewing History.
///
/// Only records:
/// - `PHYSICAL_VISIT` (when the user physically enters the 100m GPS geofence radius of a landmark)
/// - `AR_VIEW` (when the user opens a 3D / AR reconstruction)
/// Simply viewing a landmark's details page (`PAGE_VIEW`) is never counted as a visit.
class HistoryService {
  HistoryService._();
  static final HistoryService instance = HistoryService._();

  static const String _storageKey = 'daanar_field_history_v2';

  /// Notifies listeners (`FieldHistoryScreen`) whenever entries change.
  final ValueNotifier<int> revision = ValueNotifier<int>(0);

  /// Loads all saved history entries sorted newest-first.
  Future<List<HistoryEntry>> loadEntries({List<Landmark>? knownLandmarks}) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_storageKey);

    List<HistoryEntry> entries = [];
    if (raw != null && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is List) {
          entries = decoded
              .whereType<Map<String, dynamic>>()
              .map(HistoryEntry.fromJson)
              .toList();
        }
      } catch (_) {
        entries = [];
      }
    }

    if (knownLandmarks != null && knownLandmarks.isNotEmpty && entries.isNotEmpty) {
      bool updated = false;
      final enriched = entries.map((entry) {
        final matched = _matchLandmark(entry, knownLandmarks);
        if (matched == null) return entry;
        final nextHero = matched.media.heroImage ?? entry.heroImageUrl;
        final nextMuni = matched.municipality?.name ?? entry.municipalityName;
        final nextId = matched.id;
        if (nextHero != entry.heroImageUrl ||
            nextMuni != entry.municipalityName ||
            nextId != entry.landmarkId) {
          updated = true;
          return entry.copyWith(
            landmarkId: nextId,
            heroImageUrl: nextHero,
            municipalityName: nextMuni,
            category: matched.category,
          );
        }
        return entry;
      }).toList();

      if (updated) {
        entries = enriched;
        await _saveEntriesInternal(prefs, entries);
      }
    }

    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return entries;
  }

  /// Records a landmark visit or AR viewing event from `LandmarkService`.
  ///
  /// Strictly ignores `PAGE_VIEW` and `MAP_NAV` so `PLACES VISITED` only increments
  /// when the user physically enters the landmark's GPS geofence radius (`PHYSICAL_VISIT`).
  Future<void> recordFromAnalytics({
    required int landmarkId,
    required String actionType,
    String? verificationMethod,
    Landmark? landmark,
  }) async {
    final HistoryEntryType? type;
    if (actionType == 'AR_VIEW') {
      type = HistoryEntryType.ar;
    } else if (actionType == 'PHYSICAL_VISIT') {
      type = HistoryEntryType.visit;
    } else {
      // Ignore PAGE_VIEW and MAP_NAV: viewing a landmark in the app does NOT count as a visit
      type = null;
    }

    if (type == null) return;

    final resolved = landmark ?? await _resolveLandmarkFromCache(landmarkId);
    final name = resolved?.name ?? 'Landmark #$landmarkId';
    final municipality = resolved?.municipality?.name ?? 'Pangasinan';
    final category = resolved?.category ?? 'historical';
    final heroImage = resolved?.media.heroImage;

    final String subtitle;
    if (type == HistoryEntryType.ar) {
      subtitle = _buildArSubtitle(name, category);
    } else {
      subtitle = 'On-site visit · Verified GPS';
    }

    await recordEntry(
      landmarkId: landmarkId,
      landmarkName: name,
      municipalityName: municipality,
      heroImageUrl: heroImage,
      category: category,
      type: type,
      subtitle: subtitle,
      isVerifiedGps: actionType == 'PHYSICAL_VISIT',
    );
  }

  /// Adds or updates a history entry and notifies listeners.
  Future<void> recordEntry({
    required int landmarkId,
    required String landmarkName,
    required String municipalityName,
    String? heroImageUrl,
    required String category,
    required HistoryEntryType type,
    required String subtitle,
    bool isVerifiedGps = false,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final entries = await loadEntries();
    final now = DateTime.now();

    // Deduplicate repeat logs for the same landmark + type within 15 minutes
    final recentIdx = entries.indexWhere((e) =>
        e.landmarkId == landmarkId &&
        e.type == type &&
        now.difference(e.timestamp).inMinutes.abs() < 15);

    if (recentIdx >= 0) {
      final existing = entries[recentIdx];
      final upgradedSubtitle = isVerifiedGps ? subtitle : existing.subtitle;
      entries[recentIdx] = existing.copyWith(
        landmarkName: landmarkName,
        municipalityName: municipalityName,
        heroImageUrl: heroImageUrl ?? existing.heroImageUrl,
        category: category,
        subtitle: upgradedSubtitle,
        timestamp: now,
      );
    } else {
      final newEntry = HistoryEntry(
        id: '${landmarkId}_${type.name}_${now.millisecondsSinceEpoch}',
        landmarkId: landmarkId,
        landmarkName: landmarkName,
        municipalityName: municipalityName,
        heroImageUrl: heroImageUrl,
        category: category,
        type: type,
        subtitle: subtitle,
        timestamp: now,
      );
      entries.insert(0, newEntry);
    }

    entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    await _saveEntriesInternal(prefs, entries);
    revision.value++;
  }

  /// Clears all user visit and AR viewing history.
  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, jsonEncode(const <Map<String, dynamic>>[]));
    revision.value++;
  }

  Future<void> _saveEntriesInternal(
    SharedPreferences prefs,
    List<HistoryEntry> entries,
  ) async {
    final encoded = jsonEncode(entries.map((e) => e.toJson()).toList());
    await prefs.setString(_storageKey, encoded);
  }

  String _buildArSubtitle(String name, String category) {
    final lower = name.toLowerCase();
    if (lower.contains('monument') || lower.contains('battle')) {
      return '3D monument reconstruction';
    }
    if (lower.contains('station') ||
        lower.contains('railway') ||
        lower.contains('pnr')) {
      return 'Then & now portal';
    }
    if (category.toLowerCase() == 'church' ||
        lower.contains('basilica') ||
        lower.contains('parish') ||
        lower.contains('santuario')) {
      return '3D architectural reconstruction';
    }
    return '3D & AR model inspection';
  }

  Future<Landmark?> _resolveLandmarkFromCache(int landmarkId) async {
    try {
      final detailMap = await CacheService.loadMap(
        CacheService.landmarkDetailKey(landmarkId),
      );
      if (detailMap != null) {
        return Landmark.fromJson(detailMap);
      }

      final allList = await CacheService.loadList(CacheService.keyLandmarks);
      if (allList != null) {
        for (final item in allList) {
          if ((item['id'] as num?)?.toInt() == landmarkId) {
            return Landmark.fromJson(item);
          }
        }
      }

      final featuredList = await CacheService.loadList(
        CacheService.keyFeaturedLandmarks,
      );
      if (featuredList != null) {
        for (final item in featuredList) {
          if ((item['id'] as num?)?.toInt() == landmarkId) {
            return Landmark.fromJson(item);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  Landmark? _matchLandmark(HistoryEntry entry, List<Landmark> landmarks) {
    for (final lm in landmarks) {
      if (lm.id == entry.landmarkId) return lm;
    }
    final target = entry.landmarkName.toLowerCase();
    for (final lm in landmarks) {
      final lmName = lm.name.toLowerCase();
      if (lmName == target ||
          lmName.contains(target) ||
          target.contains(lmName)) {
        return lm;
      }
    }
    return null;
  }
}
