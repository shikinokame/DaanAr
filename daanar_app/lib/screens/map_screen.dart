import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/theme.dart';
import '../models/landmark.dart';
import '../providers/landmark_providers.dart';
import '../providers/municipality_providers.dart';
import '../widgets/category_badge.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  String? _selectedMunicipality;
  Landmark? _selectedLandmark;

  // Default center: Dagupan City area
  static const _initialPosition = CameraPosition(
    target: LatLng(16.0430, 120.3333),
    zoom: 11.5,
  );

  @override
  void dispose() {
    _mapController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final landmarksAsync = ref.watch(landmarkListProvider);
    final municipalitiesAsync = ref.watch(municipalityListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Heritage Map'),
        actions: [
          if (_selectedMunicipality != null)
            IconButton(
              icon: const Icon(Icons.filter_alt_off),
              tooltip: 'Clear filter',
              onPressed: () => setState(() => _selectedMunicipality = null),
            ),
        ],
      ),
      body: Stack(
        children: [
          // ── Google Map ────────────────────────────────────────────────────
          landmarksAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (e, _) => Center(child: Text('Error: $e')),
            data: (result) {
              final filtered = _selectedMunicipality == null
                  ? result.landmarks
                  : result.landmarks
                      .where((l) => l.municipality?.name == _selectedMunicipality)
                      .toList();

              final markers = filtered
                  .map(
                    (l) => Marker(
                      markerId: MarkerId(l.id.toString()),
                      position: LatLng(l.lat, l.lng),
                      infoWindow: InfoWindow(title: l.name, snippet: l.category),
                      icon: BitmapDescriptor.defaultMarkerWithHue(
                        _categoryHue(l.category),
                      ),
                      onTap: () => setState(() => _selectedLandmark = l),
                    ),
                  )
                  .toSet();

              return GoogleMap(
                initialCameraPosition: _initialPosition,
                markers: markers,
                myLocationButtonEnabled: false,
                zoomControlsEnabled: false,
                mapToolbarEnabled: false,
                onMapCreated: (controller) => _mapController = controller,
                onTap: (_) => setState(() => _selectedLandmark = null),
              );
            },
          ),

          // ── Municipality filter chips (top overlay) ───────────────────────
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: municipalitiesAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _1) => const SizedBox.shrink(),
              data: (result) => Container(
                color: Colors.white.withValues(alpha: 0.93),
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      _filterChip('All', _selectedMunicipality == null, () {
                        setState(() => _selectedMunicipality = null);
                      }),
                      ...result.municipalities.map((m) => _filterChip(
                            m.name,
                            _selectedMunicipality == m.name,
                            () {
                              setState(() => _selectedMunicipality = m.name);
                              // Re-center map on the municipality
                              _mapController?.animateCamera(
                                CameraUpdate.newLatLngZoom(
                                  LatLng(m.lat, m.lng),
                                  13,
                                ),
                              );
                            },
                          )),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Selected landmark bottom sheet ────────────────────────────────
          if (_selectedLandmark != null)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _LandmarkPreviewSheet(
                landmark: _selectedLandmark!,
                onClose: () => setState(() => _selectedLandmark = null),
                onViewDetails: () => context.push('/landmarks/${_selectedLandmark!.id}'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label, style: const TextStyle(fontSize: 12)),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: AppColors.primary,
        labelStyle: TextStyle(
          color: selected ? Colors.white : AppColors.charcoal,
          fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
        ),
        backgroundColor: AppColors.cardBg,
        side: BorderSide(color: selected ? AppColors.primary : AppColors.divider),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      ),
    );
  }

  double _categoryHue(String cat) => switch (cat) {
    'church'    => BitmapDescriptor.hueOrange,
    'park'      => BitmapDescriptor.hueGreen,
    'historical'=> BitmapDescriptor.hueViolet,
    'natural'   => BitmapDescriptor.hueCyan,
    'cultural'  => BitmapDescriptor.hueMagenta,
    _           => BitmapDescriptor.hueRed,
  };
}

class _LandmarkPreviewSheet extends StatelessWidget {
  final Landmark landmark;
  final VoidCallback onClose;
  final VoidCallback onViewDetails;

  const _LandmarkPreviewSheet({
    required this.landmark,
    required this.onClose,
    required this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: (AppColors.categoryColors[landmark.category] ?? AppColors.primary)
                    .withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                switch (landmark.category) {
                  'church'    => Icons.church,
                  'park'      => Icons.park,
                  'historical'=> Icons.account_balance,
                  'natural'   => Icons.landscape,
                  'cultural'  => Icons.museum,
                  _           => Icons.place,
                },
                color: AppColors.categoryColors[landmark.category] ?? AppColors.primary,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    landmark.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                      color: AppColors.charcoal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      CategoryBadge(category: landmark.category, small: true),
                      const SizedBox(width: 6),
                      Text(
                        landmark.municipality?.name ?? '',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: AppColors.textMuted),
                  onPressed: onClose,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
                const SizedBox(height: 6),
                ElevatedButton(
                  onPressed: onViewDetails,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: const Text('Details', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
