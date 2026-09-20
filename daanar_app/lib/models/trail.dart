import 'landmark.dart';
import 'municipality.dart';

class Trail {
  final int id;
  final String name;
  final String description;
  final String difficulty;
  final int estimatedTime; // in minutes
  final Municipality? municipality;
  final List<Landmark> landmarks;
  final int? landmarksCount;

  const Trail({
    required this.id,
    required this.name,
    required this.description,
    required this.difficulty,
    required this.estimatedTime,
    this.municipality,
    this.landmarks = const [],
    this.landmarksCount,
  });

  factory Trail.fromJson(Map<String, dynamic> json) {
    final municipalityJson = json['municipality'];
    final landmarksJson = json['landmarks'] as List<dynamic>? ?? [];

    return Trail(
      id: json['id'] as int,
      name: json['name'] as String,
      description: json['description'] as String? ?? '',
      difficulty: json['difficulty'] as String,
      estimatedTime: json['estimated_time'] as int,
      municipality: municipalityJson != null
          ? Municipality.fromJson(municipalityJson as Map<String, dynamic>)
          : null,
      landmarks: landmarksJson
          .map((l) => Landmark.fromJson(l as Map<String, dynamic>))
          .toList(),
      landmarksCount: json['landmarks_count'] as int?,
    );
  }
}
