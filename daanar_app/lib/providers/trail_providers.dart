import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/trail.dart';
import '../services/trail_service.dart';

class TrailResult {
  final List<Trail> trails;
  final bool fromCache;
  const TrailResult({required this.trails, required this.fromCache});
}

class TrailDetailResult {
  final Trail trail;
  final bool fromCache;
  const TrailDetailResult({required this.trail, required this.fromCache});
}

final trailListProvider = FutureProvider<TrailResult>((ref) async {
  final result = await ref.read(trailServiceProvider).fetchAll();
  return TrailResult(trails: result.trails, fromCache: result.fromCache);
});

final trailDetailProvider =
    FutureProvider.family<TrailDetailResult, int>((ref, id) async {
  final result = await ref.read(trailServiceProvider).fetchById(id);
  return TrailDetailResult(trail: result.trail, fromCache: result.fromCache);
});
