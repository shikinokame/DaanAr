import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/municipality.dart';
import '../services/municipality_service.dart';

class MunicipalityResult {
  final List<Municipality> municipalities;
  final bool fromCache;
  const MunicipalityResult({
    required this.municipalities,
    required this.fromCache,
  });
}

final municipalityListProvider =
    FutureProvider<MunicipalityResult>((ref) async {
  final result = await ref.read(municipalityServiceProvider).fetchAll();
  return MunicipalityResult(
    municipalities: result.municipalities,
    fromCache: result.fromCache,
  );
});
