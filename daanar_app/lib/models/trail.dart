import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'landmark.dart';
import 'municipality.dart';

class TrailStep {
  final String instruction;
  final int distanceM;
  final int durationS;
  final String name;

  const TrailStep({
    required this.instruction,
    required this.distanceM,
    required this.durationS,
    this.name = '',
  });

  factory TrailStep.fromJson(Map<String, dynamic> json) {
    return TrailStep(
      instruction: json['instruction'] as String? ?? 'Continue along route',
      distanceM: (json['distance_m'] as num?)?.toInt() ?? 0,
      durationS: (json['duration_s'] as num?)?.toInt() ?? 0,
      name: json['name'] as String? ?? '',
    );
  }
}

class TrailSegment {
  final int id;
  final int order;
  final int fromLandmarkId;
  final int toLandmarkId;
  final List<LatLng> points;
  final int distanceM;
  final int durationS;
  final List<TrailStep> steps;

  const TrailSegment({
    required this.id,
    required this.order,
    required this.fromLandmarkId,
    required this.toLandmarkId,
    this.points = const [],
    this.distanceM = 0,
    this.durationS = 0,
    this.steps = const [],
  });

  factory TrailSegment.fromJson(Map<String, dynamic> json) {
    final rawPoints = json['points'] as List<dynamic>? ?? [];
    final parsedPoints = <LatLng>[];
    for (final p in rawPoints) {
      if (p is List && p.length >= 2) {
        parsedPoints.add(
          LatLng((p[0] as num).toDouble(), (p[1] as num).toDouble()),
        );
      } else if (p is Map<String, dynamic>) {
        final lat = (p['lat'] as num?)?.toDouble();
        final lng = (p['lng'] as num?)?.toDouble();
        if (lat != null && lng != null) {
          parsedPoints.add(LatLng(lat, lng));
        }
      }
    }

    final rawSteps = json['steps'] as List<dynamic>? ?? [];

    return TrailSegment(
      id: (json['id'] as num?)?.toInt() ?? 0,
      order: (json['order'] as num?)?.toInt() ?? 1,
      fromLandmarkId: (json['from_landmark_id'] as num?)?.toInt() ?? 0,
      toLandmarkId: (json['to_landmark_id'] as num?)?.toInt() ?? 0,
      points: parsedPoints,
      distanceM: (json['distance_m'] as num?)?.toInt() ?? 0,
      durationS: (json['duration_s'] as num?)?.toInt() ?? 0,
      steps: rawSteps
          .whereType<Map<String, dynamic>>()
          .map(TrailStep.fromJson)
          .toList(),
    );
  }

  String get distanceLabel {
    if (distanceM >= 1000) {
      return '${(distanceM / 1000).toStringAsFixed(1)} km';
    }
    return '$distanceM m';
  }

  String get durationLabel {
    final mins = (durationS / 60).ceil();
    if (mins < 1) return '1 min';
    if (mins < 60) return '$mins min';
    final hrs = mins ~/ 60;
    final rem = mins % 60;
    return rem == 0 ? '$hrs hr' : '$hrs hr $rem min';
  }
}

class Trail {
  final int id;
  final String name;
  final String description;
  final String? district;
  final String difficulty;
  final int estimatedTime; // in minutes
  final int? totalDistanceMetres;
  final Municipality? municipality;
  final List<Landmark> landmarks;
  final int? landmarksCount;
  final List<TrailSegment> segments;

  const Trail({
    required this.id,
    required this.name,
    required this.description,
    this.district,
    required this.difficulty,
    required this.estimatedTime,
    this.totalDistanceMetres,
    this.municipality,
    this.landmarks = const [],
    this.landmarksCount,
    this.segments = const [],
  });

  factory Trail.fromJson(Map<String, dynamic> json) {
    final municipalityJson = json['municipality'];
    final landmarksJson = json['landmarks'] as List<dynamic>? ?? [];
    // Live Google routes are fetched from the user's current position.
    // Do not reuse legacy ORS or straight-line fallback segments.

    return Trail(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      district: json['district'] as String?,
      difficulty: json['difficulty'] as String? ?? 'easy',
      estimatedTime: (json['estimated_time'] as num?)?.toInt() ?? 30,
      totalDistanceMetres: (json['total_distance_metres'] as num?)?.toInt(),
      municipality: municipalityJson != null
          ? Municipality.fromJson(municipalityJson as Map<String, dynamic>)
          : null,
      landmarks: landmarksJson
          .whereType<Map<String, dynamic>>()
          .map(Landmark.fromJson)
          .toList(),
      landmarksCount: (json['landmarks_count'] as num?)?.toInt(),
      segments: const [],
    );
  }

  int get stopCount =>
      landmarks.isNotEmpty ? landmarks.length : (landmarksCount ?? 0);

  String get coverageLabel =>
      municipality?.name ?? district ?? 'Pangasinan Heritage Circuit';

  String get distanceLabel {
    final dist =
        totalDistanceMetres ??
        segments.fold<int>(0, (sum, s) => sum + s.distanceM);
    if (dist <= 0) return 'Multi-stop';
    if (dist >= 1000) {
      return '${(dist / 1000).toStringAsFixed(1)} km';
    }
    return '$dist m';
  }

  String get durationLabel {
    if (estimatedTime < 60) return '$estimatedTime min';
    final hrs = estimatedTime ~/ 60;
    final mins = estimatedTime % 60;
    return mins == 0 ? '$hrs hr' : '$hrs hr $mins min';
  }

  /// Returns all polyline coordinates across the entire trail.
  List<LatLng> get fullPolylinePoints {
    if (segments.isNotEmpty) {
      final pts = <LatLng>[];
      for (final seg in segments) {
        if (seg.points.isNotEmpty) {
          pts.addAll(seg.points);
        }
      }
      if (pts.isNotEmpty) return pts;
    }
    return const <LatLng>[];
  }

  /// Finds the precomputed segment leading to [stopIndex] (`stopIndex - 1 -> stopIndex`).
  TrailSegment? segmentToStop(int stopIndex) {
    if (stopIndex <= 0 || stopIndex >= landmarks.length) return null;
    final fromId = landmarks[stopIndex - 1].id;
    final toId = landmarks[stopIndex].id;
    for (final s in segments) {
      if ((s.fromLandmarkId == fromId && s.toLandmarkId == toId) ||
          s.order == stopIndex) {
        return s;
      }
    }
    return null;
  }
}
