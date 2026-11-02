import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';

import '../core/constants.dart';
import '../core/theme.dart';
import '../models/landmark.dart';
import '../models/route_result.dart';
import '../models/trail.dart';
import '../models/transport_mode.dart';
import '../providers/landmark_providers.dart';
import '../providers/location_provider.dart';
import '../providers/municipality_providers.dart';
import '../providers/trail_providers.dart';
import '../services/landmark_service.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../widgets/archival.dart';
import 'ar_direction_screen.dart';
import 'ar_view_screen.dart';

enum AtlasMapStyle { archival, hybrid, standard }

const String _kArchivalMapStyleJson = '''
[
  {"elementType":"geometry","stylers":[{"color":"#f2ece0"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#3d3528"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#f7f3ea"},{"weight":3}]},
  {"featureType":"administrative","elementType":"geometry.stroke","stylers":[{"color":"#b8a582"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#1b4332"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#ece4d4"}]},
  {"featureType":"poi","elementType":"geometry","stylers":[{"color":"#e4decb"}]},
  {"featureType":"poi.business","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"geometry.fill","stylers":[{"color":"#dce3d1"}]},
  {"featureType":"poi.park","elementType":"labels.text.fill","stylers":[{"color":"#355843"}]},
  {"featureType":"poi.place_of_worship","elementType":"labels.text.fill","stylers":[{"color":"#6e511c"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#fbf7ee"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#e7dcc7"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#dcc9a6"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#bfa67a"}]},
  {"featureType":"road.local","elementType":"labels.text.fill","stylers":[{"color":"#6e6453"}]},
  {"featureType":"transit.line","elementType":"geometry","stylers":[{"color":"#b69f78"}]},
  {"featureType":"transit.station.rail","elementType":"labels.text.fill","stylers":[{"color":"#5c4419"}]},
  {"featureType":"water","elementType":"geometry.fill","stylers":[{"color":"#b8cbd0"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#3b565e"}]}
]
''';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key});

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  GoogleMapController? _mapController;
  late final PageController _carouselController;

  String? _selectedMunicipality;
  String? _selectedEra;
  Landmark? _selectedLandmark;

  AtlasMapStyle _atlasStyle = AtlasMapStyle.archival;
  bool _is3DTilted = true;
  bool _showTrailOverlay = false;
  bool _showCarousel = true;
  bool _showModePicker = false;
  double _currentBearing = 0.0;
  double _currentZoom = 11.5;

  Timer? _orbitTimer;
  bool _isOrbiting = false;
  bool _programmaticPageChange = false;

  // Cached custom marker bitmaps keyed by "<folio>_<selected>_<isDest>_<arReady>"
  final Map<String, BitmapDescriptor> _pinIconCache = {};
  BitmapDescriptor? _userDotIcon;

  // Route state
  RouteResult? _activeRoute;
  Landmark? _routeDestination;
  bool _isCalculatingRoute = false;

  // Live navigation state
  StreamSubscription<dynamic>? _positionSubscription;
  bool _isNavMode = false;
  LatLng? _livePosition;
  double? _remainingMetres;
  bool _autoCenter = true;

  // Rerouting & proximity state
  bool _isRerouting = false;
  bool _arPromptShown = false;
  bool _showArProximityBanner = false;
  bool _physicalVisitLogged = false;

  TransportMode _selectedMode = TransportMode.walking;

  static const _initialPosition = CameraPosition(
    target: LatLng(16.0650, 120.4020),
    zoom: 11.6,
  );

  static const _eras = <String>[
    'Spanish Colonial',
    'American Colonial',
    'Philippine-American War',
  ];

  @override
  void initState() {
    super.initState();
    _carouselController = PageController(viewportFraction: 0.87);
    _prepareUserDotIcon();
  }

  @override
  void dispose() {
    _orbitTimer?.cancel();
    _positionSubscription?.cancel();
    _carouselController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _prepareUserDotIcon() async {
    const size = 44.0;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    const center = Offset(size / 2, size / 2);

    canvas.drawCircle(
      center,
      20,
      Paint()..color = const Color(0x331B4332),
    );
    canvas.drawCircle(
      center,
      10,
      Paint()..color = AppColors.surface,
    );
    canvas.drawCircle(
      center,
      7.5,
      Paint()..color = const Color(0xFF1D6F8A),
    );

    final img = await recorder.endRecording().toImage(size.toInt(), size.toInt());
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    if (bytes != null && mounted) {
      setState(() {
        _userDotIcon = BitmapDescriptor.bytes(
          bytes.buffer.asUint8List(),
          width: 26,
          height: 26,
        );
      });
    }
  }

  Future<void> _ensureLandmarkPinIcons(List<Landmark> landmarks) async {
    bool added = false;
    for (var i = 0; i < landmarks.length; i++) {
      final lm = landmarks[i];
      for (final selected in const [false, true]) {
        for (final isDest in const [false, true]) {
          final key = '${lm.id}_${selected}_${isDest}_${lm.isArReady}';
          if (_pinIconCache.containsKey(key)) continue;
          final icon = await _renderArchivalPin(
            folioNumber: lm.id,
            selected: selected,
            isDestination: isDest,
            arReady: lm.isArReady,
          );
          if (icon != null) {
            _pinIconCache[key] = icon;
            added = true;
          }
        }
      }
    }
    if (added && mounted) {
      setState(() {});
    }
  }

  Future<BitmapDescriptor?> _renderArchivalPin({
    required int folioNumber,
    required bool selected,
    required bool isDestination,
    required bool arReady,
  }) async {
    final double w = selected ? 92 : 76;
    final double h = selected ? 110 : 92;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final Color bodyColor = isDestination
        ? const Color(0xFF8C2D19)
        : (selected ? AppColors.brass : AppColors.inkDeep);
    final Color rimColor = selected ? AppColors.inkDeep : AppColors.brass;
    final Color textColor =
        isDestination ? AppColors.surface : (selected ? AppColors.inkDeep : AppColors.surface);

    final cx = w / 2;
    final r = selected ? 31.0 : 25.0;
    final cy = r + 8.0;
    final tipY = h - 6.0;

    // Soft drop shadow
    canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, tipY + 1), width: r * 0.9, height: 6),
      Paint()..color = const Color(0x44000000),
    );

    // Pointer tail
    final tail = Path()
      ..moveTo(cx - r * 0.44, cy + r * 0.68)
      ..lineTo(cx, tipY)
      ..lineTo(cx + r * 0.44, cy + r * 0.68)
      ..close();
    canvas.drawPath(tail, Paint()..color = rimColor);

    final innerTail = Path()
      ..moveTo(cx - r * 0.34, cy + r * 0.68)
      ..lineTo(cx, tipY - 3.5)
      ..lineTo(cx + r * 0.34, cy + r * 0.68)
      ..close();
    canvas.drawPath(innerTail, Paint()..color = bodyColor);

    // Outer brass/ink medallion ring
    canvas.drawCircle(Offset(cx, cy), r, Paint()..color = rimColor);
    canvas.drawCircle(Offset(cx, cy), r - 2.6, Paint()..color = bodyColor);
    canvas.drawCircle(
      Offset(cx, cy),
      r - 5.2,
      Paint()
        ..color = rimColor.withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.1,
    );

    // Folio number label inside medallion
    final folioStr = folioNumber.toString().padLeft(2, '0');
    final tp = TextPainter(
      text: TextSpan(
        text: folioStr,
        style: TextStyle(
          fontFamily: AppFonts.serif,
          fontSize: selected ? 23 : 19,
          fontWeight: FontWeight.w700,
          color: textColor,
          height: 1.0,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, Offset(cx - tp.width / 2, cy - tp.height / 2));

    // Small top-right badge dot if 3D/AR model is available
    if (arReady) {
      final bx = cx + r * 0.68;
      final by = cy - r * 0.68;
      canvas.drawCircle(Offset(bx, by), 7.5, Paint()..color = AppColors.inkDeep);
      canvas.drawCircle(Offset(bx, by), 5.6, Paint()..color = AppColors.brass);
    }

    final img = await recorder.endRecording().toImage(w.toInt(), h.toInt());
    final ByteData? byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    if (byteData == null) return null;

    return BitmapDescriptor.bytes(
      byteData.buffer.asUint8List(),
      width: selected ? 44 : 36,
      height: selected ? 52 : 44,
    );
  }

  // Camera & interactive controls

  Future<void> _flyToLandmark(
    Landmark lm, {
    List<Landmark>? currentList,
    bool syncCarousel = true,
  }) async {
    _stopOrbit();
    setState(() {
      _selectedLandmark = lm;
      _showCarousel = true;
    });

    if (syncCarousel && currentList != null && _carouselController.hasClients) {
      final idx = currentList.indexWhere((item) => item.id == lm.id);
      if (idx >= 0) {
        _programmaticPageChange = true;
        _carouselController
            .animateToPage(
              idx,
              duration: const Duration(milliseconds: 360),
              curve: Curves.easeOutCubic,
            )
            .whenComplete(() => _programmaticPageChange = false);
      }
    }

    if (_mapController != null) {
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(lm.lat, lm.lng),
            zoom: _is3DTilted ? 17.4 : 15.8,
            tilt: _is3DTilted ? 52.0 : 0.0,
            bearing: _currentBearing,
          ),
        ),
      );
    }
  }

  Future<void> _toggle3DTilt() async {
    _stopOrbit();
    final nextTilt = !_is3DTilted;
    setState(() => _is3DTilted = nextTilt);

    if (_mapController == null) return;
    final target = _selectedLandmark != null
        ? LatLng(_selectedLandmark!.lat, _selectedLandmark!.lng)
        : (_livePosition ?? const LatLng(16.0432, 120.3338));

    final zoom = nextTilt
        ? (_currentZoom < 16.8 ? 17.3 : _currentZoom)
        : (_currentZoom > 16.2 ? 15.2 : _currentZoom);

    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: zoom,
          tilt: nextTilt ? 52.0 : 0.0,
          bearing: nextTilt ? _currentBearing : 0.0,
        ),
      ),
    );
  }

  void _toggleOrbit() {
    if (_isOrbiting) {
      _stopOrbit();
      return;
    }
    if (_mapController == null) return;
    final center = _selectedLandmark != null
        ? LatLng(_selectedLandmark!.lat, _selectedLandmark!.lng)
        : (_livePosition ?? const LatLng(16.0442, 120.4861));

    setState(() {
      _isOrbiting = true;
      _is3DTilted = true;
    });

    _orbitTimer = Timer.periodic(const Duration(milliseconds: 110), (_) {
      if (!mounted || _mapController == null || !_isOrbiting) return;
      _currentBearing = (_currentBearing + 3.2) % 360.0;
      _mapController!.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: center,
            zoom: 17.5,
            tilt: 54.0,
            bearing: _currentBearing,
          ),
        ),
      );
    });
  }

  void _stopOrbit() {
    _orbitTimer?.cancel();
    _orbitTimer = null;
    if (_isOrbiting && mounted) {
      setState(() => _isOrbiting = false);
    }
  }

  void _cycleMapStyle() {
    setState(() {
      _atlasStyle = switch (_atlasStyle) {
        AtlasMapStyle.archival => AtlasMapStyle.hybrid,
        AtlasMapStyle.hybrid => AtlasMapStyle.standard,
        AtlasMapStyle.standard => AtlasMapStyle.archival,
      };
    });
  }

  Future<void> _resetNorth() async {
    _stopOrbit();
    if (_mapController == null) return;
    final target = _selectedLandmark != null
        ? LatLng(_selectedLandmark!.lat, _selectedLandmark!.lng)
        : (_livePosition ?? const LatLng(16.0650, 120.4020));
    setState(() => _currentBearing = 0.0);
    await _mapController!.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: target,
          zoom: _currentZoom,
          tilt: _is3DTilted ? 52.0 : 0.0,
          bearing: 0.0,
        ),
      ),
    );
  }

  Future<void> _goToMyLocation() async {
    _stopOrbit();
    await ref.read(locationProvider.notifier).requestLocation();
    final locState = ref.read(locationProvider);
    if (locState is LocationReady && _mapController != null) {
      final pos = LatLng(locState.position.latitude, locState.position.longitude);
      setState(() => _livePosition = pos);
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: pos,
            zoom: _is3DTilted ? 17.0 : 15.2,
            tilt: _is3DTilted ? 48.0 : 0.0,
            bearing: _currentBearing,
          ),
        ),
      );
    } else if (locState is LocationError && mounted) {
      _showSnackBar(
        locState.message,
        action: locState.type == LocationExceptionType.permissionPermanentlyDenied
            ? SnackBarAction(
                label: 'Settings',
                textColor: AppColors.secondary,
                onPressed: openAppSettings,
              )
            : null,
      );
    }
  }

  // Routing & live GPS navigation

  Future<void> _navigateTo(Landmark destination) async {
    _stopOrbit();
    var locState = ref.read(locationProvider);
    if (locState is! LocationReady) {
      await ref.read(locationProvider.notifier).requestLocation();
      locState = ref.read(locationProvider);
    }
    if (locState is! LocationReady) {
      _showSnackBar('Enable location to use navigation.');
      return;
    }

    final originPos = LatLng(
      locState.position.latitude,
      locState.position.longitude,
    );

    ref.read(landmarkServiceProvider).logAnalyticsEvent(
          landmarkId: destination.id,
          actionType: 'MAP_NAV',
          verificationMethod: 'REMOTE',
          userLat: originPos.latitude,
          userLng: originPos.longitude,
        );

    setState(() {
      _isCalculatingRoute = true;
      _activeRoute = null;
      _routeDestination = destination;
      _livePosition = originPos;
      _physicalVisitLogged = false;
      _showModePicker = false;
    });

    try {
      final dest = LatLng(destination.lat, destination.lng);
      final route = await RoutingService.getRoute(
        origin: originPos,
        destination: dest,
        mode: _selectedMode,
      );

      setState(() {
        _activeRoute = route;
        _isCalculatingRoute = false;
        _remainingMetres = route.distanceMetres;
      });

      await _fitRouteBounds(originPos, dest);
      _startPositionStream(destination);
    } on RoutingException catch (e) {
      setState(() {
        _isCalculatingRoute = false;
        _routeDestination = null;
      });
      _showSnackBar(e.message);
    }
  }

  void _startPositionStream(Landmark destination) {
    _positionSubscription?.cancel();
    setState(() {
      _isNavMode = true;
      _autoCenter = true;
    });

    _positionSubscription = LocationService.getPositionStream().listen((position) {
      if (!mounted) return;
      final newPos = LatLng(position.latitude, position.longitude);

      final remaining = LocationService.distanceBetween(
        position.latitude,
        position.longitude,
        destination.lat,
        destination.lng,
      );

      setState(() {
        _livePosition = newPos;
        _remainingMetres = remaining;
      });

      ref.read(locationProvider.notifier).updatePosition(position);

      if (_autoCenter && _mapController != null) {
        _mapController!.animateCamera(
          CameraUpdate.newCameraPosition(
            CameraPosition(
              target: newPos,
              zoom: 17.2,
              tilt: _is3DTilted ? 50.0 : 0.0,
              bearing: position.heading.isFinite && position.heading > 0
                  ? position.heading
                  : _currentBearing,
            ),
          ),
        );
      }

      _checkAndReroute(newPos, destination);

      if (!_physicalVisitLogged &&
          remaining <= AppConstants.physicalVisitRadiusMetres) {
        _physicalVisitLogged = true;
        ref.read(landmarkServiceProvider).logAnalyticsEvent(
              landmarkId: destination.id,
              actionType: 'PHYSICAL_VISIT',
              verificationMethod: 'GPS_GEOFENCE',
              userLat: position.latitude,
              userLng: position.longitude,
            );
      }

      if (!_arPromptShown && remaining <= AppConstants.arProximityMetres) {
        setState(() {
          _arPromptShown = true;
          _showArProximityBanner = true;
        });
      }
    });
  }

  double _distanceFromRoute(LatLng point, List<LatLng> routePoints) {
    double minDist = double.infinity;
    for (final rp in routePoints) {
      final d = LocationService.distanceBetween(
        point.latitude,
        point.longitude,
        rp.latitude,
        rp.longitude,
      );
      if (d < minDist) minDist = d;
    }
    return minDist;
  }

  Future<void> _checkAndReroute(LatLng currentPos, Landmark destination) async {
    if (_activeRoute == null || _isRerouting) return;
    final deviation = _distanceFromRoute(currentPos, _activeRoute!.points);
    if (deviation <= AppConstants.rerouteThresholdMetres) return;

    setState(() => _isRerouting = true);

    try {
      final dest = LatLng(destination.lat, destination.lng);
      final newRoute = await RoutingService.getRoute(
        origin: currentPos,
        destination: dest,
        mode: _selectedMode,
      );
      if (mounted) {
        setState(() {
          _activeRoute = newRoute;
          _remainingMetres = newRoute.distanceMetres;
          _isRerouting = false;
        });
      }
    } on RoutingException {
      if (mounted) setState(() => _isRerouting = false);
    }
  }

  void _stopNavigation() {
    _positionSubscription?.cancel();
    _positionSubscription = null;
    setState(() {
      _isNavMode = false;
      _activeRoute = null;
      _routeDestination = null;
      _remainingMetres = null;
      _autoCenter = true;
      _isRerouting = false;
      _arPromptShown = false;
      _showArProximityBanner = false;
    });
  }

  Future<void> _fitRouteBounds(LatLng origin, LatLng dest) async {
    if (_mapController == null) return;
    final bounds = LatLngBounds(
      southwest: LatLng(
        origin.latitude < dest.latitude ? origin.latitude : dest.latitude,
        origin.longitude < dest.longitude ? origin.longitude : dest.longitude,
      ),
      northeast: LatLng(
        origin.latitude > dest.latitude ? origin.latitude : dest.latitude,
        origin.longitude > dest.longitude ? origin.longitude : dest.longitude,
      ),
    );
    await _mapController!.animateCamera(CameraUpdate.newLatLngBounds(bounds, 84));
  }

  void _showSnackBar(String message, {SnackBarAction? action}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: AppColors.primary,
        action: action,
      ),
    );
  }

  List<Landmark> _filterLandmarks(List<Landmark> all) {
    return all.where((l) {
      if (_selectedMunicipality != null &&
          l.municipality?.name != _selectedMunicipality) {
        return false;
      }
      if (_selectedEra != null) {
        final era = (l.era ?? '').toLowerCase();
        if (!era.contains(_selectedEra!.toLowerCase())) {
          return false;
        }
      }
      return true;
    }).toList();
  }

  Set<Polyline> _buildPolylines(List<Trail> trails) {
    final polylines = <Polyline>{};

    if (_showTrailOverlay) {
      for (final trail in trails) {
        final pts = trail.fullPolylinePoints.isNotEmpty
            ? trail.fullPolylinePoints
            : trail.landmarks.map((s) => LatLng(s.lat, s.lng)).toList();
        if (pts.length >= 2) {
          polylines.add(
            Polyline(
              polylineId: PolylineId('heritage_trail_${trail.id}'),
              points: pts,
              color: _atlasStyle == AtlasMapStyle.hybrid
                  ? AppColors.brass
                  : AppColors.brassInk,
              width: 4,
              patterns: [PatternItem.dash(18), PatternItem.gap(10)],
            ),
          );
        }
      }
    }

    if (_activeRoute != null) {
      polylines.add(
        Polyline(
          polylineId: const PolylineId('active_nav_route'),
          points: _activeRoute!.points,
          color: _atlasStyle == AtlasMapStyle.hybrid
              ? AppColors.brass
              : AppColors.primary,
          width: 6,
        ),
      );
    }

    return polylines;
  }

  Set<Circle> _buildDiscoveryCircles(List<Landmark> filtered, LatLng? userPos) {
    final circles = <Circle>{};
    for (final lm in filtered) {
      final isSelected = _selectedLandmark?.id == lm.id ||
          _routeDestination?.id == lm.id;
      if (!isSelected && _currentZoom < 14.5) continue;

      final insideZone = userPos != null &&
          LocationService.distanceBetween(
                userPos.latitude,
                userPos.longitude,
                lm.lat,
                lm.lng,
              ) <=
              AppConstants.physicalVisitRadiusMetres;

      final strokeColor = insideZone
          ? const Color(0xFF2EA043)
          : (isSelected ? AppColors.brass : AppColors.primary);

      circles.add(
        Circle(
          circleId: CircleId('geofence_${lm.id}'),
          center: LatLng(lm.lat, lm.lng),
          radius: AppConstants.physicalVisitRadiusMetres,
          strokeWidth: isSelected ? 2 : 1,
          strokeColor: strokeColor.withValues(alpha: isSelected ? 0.85 : 0.45),
          fillColor: strokeColor.withValues(alpha: isSelected ? 0.16 : 0.07),
        ),
      );
    }
    return circles;
  }

  @override
  Widget build(BuildContext context) {
    final landmarksAsync = ref.watch(landmarkListProvider);
    final municipalitiesAsync = ref.watch(municipalityListProvider);
    final trailsAsync = ref.watch(trailListProvider);
    final locationState = ref.watch(locationProvider);
    final isLocating = locationState is LocationLoading;

    final LatLng? userPos = _livePosition ??
        (locationState is LocationReady
            ? LatLng(
                locationState.position.latitude,
                locationState.position.longitude,
              )
            : null);

    final trails = trailsAsync.whenOrNull(data: (r) => r.trails) ?? const <Trail>[];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _isNavMode
          ? null
          : AppBar(
              title: Column(
                children: [
                  Text(
                    'PANGASINAN CARTOGRAPHIC ATLAS',
                    style: AppText.eyebrow.copyWith(
                      color: AppColors.brass,
                      fontSize: 9.5,
                    ),
                  ),
                  const SizedBox(height: 1),
                  const Text(
                    'Heritage Map',
                    style: TextStyle(
                      fontFamily: AppFonts.serif,
                      fontSize: 21,
                      fontWeight: FontWeight.w700,
                      color: AppColors.surface,
                    ),
                  ),
                ],
              ),
              actions: [
                if (_selectedMunicipality != null || _selectedEra != null)
                  TextButton(
                    onPressed: () {
                      _stopOrbit();
                      setState(() {
                        _selectedMunicipality = null;
                        _selectedEra = null;
                      });
                    },
                    child: Text(
                      'CLEAR',
                      style: AppText.action.copyWith(color: AppColors.brass),
                    ),
                  ),
              ],
            ),
      body: Stack(
        children: [
          // Interactive Google Map
          landmarksAsync.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
            error: (e, _) => Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Unable to load map records: $e',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textMuted),
                ),
              ),
            ),
            data: (result) {
              _ensureLandmarkPinIcons(result.landmarks);
              final filtered = _filterLandmarks(result.landmarks);

              final markers = <Marker>{
                for (final l in filtered)
                  Marker(
                    markerId: MarkerId(l.id.toString()),
                    position: LatLng(l.lat, l.lng),
                    anchor: const Offset(0.5, 0.92),
                    icon: _pinIconCache[
                            '${l.id}_${_selectedLandmark?.id == l.id}_${_routeDestination?.id == l.id}_${l.isArReady}'] ??
                        BitmapDescriptor.defaultMarkerWithHue(
                          _selectedLandmark?.id == l.id
                              ? BitmapDescriptor.hueYellow
                              : BitmapDescriptor.hueGreen,
                        ),
                    zIndexInt: _selectedLandmark?.id == l.id ? 3 : 1,
                    onTap: () => _flyToLandmark(l, currentList: filtered),
                  ),
              };

              if (userPos != null) {
                markers.add(
                  Marker(
                    markerId: const MarkerId('user_location'),
                    position: userPos,
                    anchor: const Offset(0.5, 0.5),
                    icon: _userDotIcon ??
                        BitmapDescriptor.defaultMarkerWithHue(
                          BitmapDescriptor.hueAzure,
                        ),
                    infoWindow: const InfoWindow(title: 'Your Location'),
                    zIndexInt: 4,
                  ),
                );
              }

              final mapType = _atlasStyle == AtlasMapStyle.hybrid
                  ? MapType.hybrid
                  : MapType.normal;
              final mapStyle = _atlasStyle == AtlasMapStyle.archival
                  ? _kArchivalMapStyleJson
                  : null;

              return Listener(
                onPointerMove: (event) {
                  if (event.delta.distance > 2.5) {
                    _stopOrbit();
                    if (_isNavMode && _autoCenter) {
                      setState(() => _autoCenter = false);
                    }
                  }
                },
                child: GoogleMap(
                  initialCameraPosition: _initialPosition,
                  mapType: mapType,
                  style: mapStyle,
                  buildingsEnabled: true,
                  tiltGesturesEnabled: true,
                  rotateGesturesEnabled: true,
                  compassEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  mapToolbarEnabled: false,
                  padding: EdgeInsets.only(
                    top: _isNavMode ? 96 : 94,
                    bottom: (!_isNavMode && _showCarousel && filtered.isNotEmpty)
                        ? 176
                        : 18,
                  ),
                  markers: markers,
                  polylines: _buildPolylines(trails),
                  circles: _buildDiscoveryCircles(filtered, userPos),
                  onMapCreated: (c) {
                    _mapController = c;
                    if (filtered.isNotEmpty && _selectedLandmark == null) {
                      setState(() => _selectedLandmark = filtered.first);
                    }
                  },
                  onTap: (_) {
                    _stopOrbit();
                    if (_showModePicker) {
                      setState(() => _showModePicker = false);
                    }
                  },
                  onCameraMove: (pos) {
                    _currentBearing = pos.bearing;
                    _currentZoom = pos.zoom;
                  },
                ),
              );
            },
          ),

          // Top archival filter ledger (Municipalities + Historical Eras)
          if (!_isNavMode)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.surface.withValues(alpha: 0.95),
                  border: const Border(
                    bottom: BorderSide(color: AppColors.rule, width: 1),
                  ),
                ),
                padding: const EdgeInsets.only(top: 8, bottom: 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    municipalitiesAsync.when(
                      loading: () => const SizedBox(height: 32),
                      error: (_, _) => const SizedBox.shrink(),
                      data: (result) => SizedBox(
                        height: 32,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            _archivalFilterTab(
                              label: 'All Places',
                              selected: _selectedMunicipality == null,
                              onTap: () {
                                _stopOrbit();
                                setState(() => _selectedMunicipality = null);
                                _mapController?.animateCamera(
                                  CameraUpdate.newCameraPosition(_initialPosition),
                                );
                              },
                            ),
                            ...result.municipalities.map(
                              (m) => _archivalFilterTab(
                                label: m.name,
                                selected: _selectedMunicipality == m.name,
                                onTap: () {
                                  _stopOrbit();
                                  setState(() => _selectedMunicipality = m.name);
                                  _mapController?.animateCamera(
                                    CameraUpdate.newCameraPosition(
                                      CameraPosition(
                                        target: LatLng(m.lat, m.lng),
                                        zoom: _is3DTilted ? 14.8 : 13.5,
                                        tilt: _is3DTilted ? 45.0 : 0.0,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    SizedBox(
                      height: 26,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        children: [
                          _eraChip(
                            label: 'All Eras',
                            selected: _selectedEra == null,
                            onTap: () => setState(() => _selectedEra = null),
                          ),
                          ..._eras.map(
                            (era) => _eraChip(
                              label: era,
                              selected: _selectedEra == era,
                              onTap: () => setState(
                                () => _selectedEra =
                                    _selectedEra == era ? null : era,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Right-side floating cartographic controls (Style / 3D Tilt / Orbit / Trails / Compass / GPS)
          Positioned(
            top: _isNavMode
                ? MediaQuery.of(context).padding.top + 92
                : 98,
            right: 12,
            child: Column(
              children: [
                _MapControlButton(
                  icon: switch (_atlasStyle) {
                    AtlasMapStyle.archival => Icons.auto_stories_outlined,
                    AtlasMapStyle.hybrid => Icons.satellite_alt_outlined,
                    AtlasMapStyle.standard => Icons.map_outlined,
                  },
                  label: switch (_atlasStyle) {
                    AtlasMapStyle.archival => 'VINTAGE',
                    AtlasMapStyle.hybrid => 'SATELLITE',
                    AtlasMapStyle.standard => 'STANDARD',
                  },
                  active: _atlasStyle != AtlasMapStyle.standard,
                  onTap: _cycleMapStyle,
                ),
                const SizedBox(height: 8),
                _MapControlButton(
                  icon: Icons.threed_rotation_outlined,
                  label: _is3DTilted ? '3D TILT' : '2D FLAT',
                  active: _is3DTilted,
                  onTap: _toggle3DTilt,
                ),
                if (!_isNavMode) ...[
                  const SizedBox(height: 8),
                  _MapControlButton(
                    icon: _isOrbiting
                        ? Icons.pause_circle_outline
                        : Icons.rotate_90_degrees_ccw_outlined,
                    label: 'ORBIT',
                    active: _isOrbiting,
                    onTap: _toggleOrbit,
                  ),
                  const SizedBox(height: 8),
                  _MapControlButton(
                    icon: Icons.route_outlined,
                    label: 'TRAILS',
                    active: _showTrailOverlay,
                    onTap: () =>
                        setState(() => _showTrailOverlay = !_showTrailOverlay),
                  ),
                ],
                if (_currentBearing.abs() > 3.0) ...[
                  const SizedBox(height: 8),
                  _MapControlButton(
                    icon: Icons.explore_outlined,
                    label: 'NORTH',
                    active: false,
                    onTap: _resetNorth,
                  ),
                ],
                if (!_isNavMode) ...[
                  const SizedBox(height: 8),
                  _MapControlButton(
                    icon: Icons.my_location_outlined,
                    label: isLocating ? 'WAIT' : 'LOCATE',
                    active: false,
                    onTap: isLocating ? null : _goToMyLocation,
                  ),
                ],
              ],
            ),
          ),

          // Route calculating banner
          if (_isCalculatingRoute)
            Positioned(
              top: _isNavMode ? MediaQuery.of(context).padding.top + 12 : 100,
              left: 12,
              right: 76,
              child: EngravedFrame(
                fill: AppColors.surface,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                child: const Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    SizedBox(width: 10),
                    Text(
                      'Plotting route across Pangasinan…',
                      style: TextStyle(
                        fontFamily: AppFonts.serif,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Live Navigation HUD
          if (_isNavMode && _routeDestination != null)
            _LiveNavPanel(
              destination: _routeDestination!,
              remainingMetres: _remainingMetres,
              initialRoute: _activeRoute,
              autoCenter: _autoCenter,
              isRerouting: _isRerouting,
              mode: _selectedMode,
              onRecenter: () {
                setState(() => _autoCenter = true);
                if (userPos != null && _mapController != null) {
                  _mapController!.animateCamera(
                    CameraUpdate.newCameraPosition(
                      CameraPosition(
                        target: userPos,
                        zoom: 17.2,
                        tilt: _is3DTilted ? 50.0 : 0.0,
                        bearing: _currentBearing,
                      ),
                    ),
                  );
                }
              },
              onStop: _stopNavigation,
            ),

          // Proximity AR Launch Banner (within 50m of destination)
          if (_isNavMode && _showArProximityBanner && _routeDestination != null)
            Positioned(
              bottom: 92,
              left: 12,
              right: 12,
              child: _ArProximityBanner(
                destination: _routeDestination!,
                onViewAR: () {
                  setState(() => _showArProximityBanner = false);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ARViewScreen(
                        landmarkId: _routeDestination!.id,
                        landmarkName: _routeDestination!.name,
                      ),
                    ),
                  );
                },
                onDismiss: () => setState(() => _showArProximityBanner = false),
              ),
            ),

          // Bottom Interactive Swipeable "Fly-To" Landmark Carousel
          if (!_isNavMode)
            landmarksAsync.when(
              loading: () => const SizedBox.shrink(),
              error: (_, _) => const SizedBox.shrink(),
              data: (result) {
                final filtered = _filterLandmarks(result.landmarks);
                if (filtered.isEmpty) {
                  return Positioned(
                    bottom: 16,
                    left: 16,
                    right: 16,
                    child: EngravedFrame(
                      fill: AppColors.surface,
                      padding: const EdgeInsets.all(14),
                      child: const Text(
                        'No landmarks match the selected filter.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: AppFonts.serif,
                          fontSize: 16,
                          color: AppColors.charcoal,
                        ),
                      ),
                    ),
                  );
                }

                return Positioned(
                  left: 0,
                  right: 0,
                  bottom: 10,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Collapse / Expand Carousel Handle + Site Counter
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            GestureDetector(
                              onTap: () =>
                                  setState(() => _showCarousel = !_showCarousel),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.inkDeep.withValues(alpha: 0.92),
                                  border: Border.all(
                                    color: AppColors.brass.withValues(alpha: 0.55),
                                    width: 0.8,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      _showCarousel
                                          ? Icons.keyboard_arrow_down
                                          : Icons.keyboard_arrow_up,
                                      size: 14,
                                      color: AppColors.brass,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      _showCarousel
                                          ? 'HIDE ATLAS CARDS (${filtered.length})'
                                          : 'SHOW ATLAS CARDS (${filtered.length})',
                                      style: AppText.meta.copyWith(
                                        color: AppColors.surface,
                                        fontSize: 9.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (_showModePicker && _selectedLandmark != null)
                              _TransportModeMiniBar(
                                selectedMode: _selectedMode,
                                onSelect: (m) {
                                  setState(() => _selectedMode = m);
                                  _navigateTo(_selectedLandmark!);
                                },
                              ),
                          ],
                        ),
                      ),
                      if (_showCarousel) ...[
                        const SizedBox(height: 8),
                        SizedBox(
                          height: 158,
                          child: PageView.builder(
                            controller: _carouselController,
                            itemCount: filtered.length,
                            onPageChanged: (idx) {
                              if (_programmaticPageChange) return;
                              _flyToLandmark(
                                filtered[idx],
                                currentList: filtered,
                                syncCarousel: false,
                              );
                            },
                            itemBuilder: (context, idx) {
                              final lm = filtered[idx];
                              final selected = _selectedLandmark?.id == lm.id;
                              final distM = userPos != null
                                  ? LocationService.distanceBetween(
                                      userPos.latitude,
                                      userPos.longitude,
                                      lm.lat,
                                      lm.lng,
                                    )
                                  : null;

                              return Padding(
                                padding:
                                    const EdgeInsets.symmetric(horizontal: 6),
                                child: _AtlasCarouselCard(
                                  landmark: lm,
                                  isSelected: selected,
                                  isCalculating: _isCalculatingRoute &&
                                      _routeDestination?.id == lm.id,
                                  distanceMetres: distM,
                                  selectedMode: _selectedMode,
                                  onTapCard: () => _flyToLandmark(
                                    lm,
                                    currentList: filtered,
                                  ),
                                  onTapModeToggle: () {
                                    setState(() {
                                      _selectedLandmark = lm;
                                      _showModePicker = !_showModePicker;
                                    });
                                  },
                                  onNavigate: () => _navigateTo(lm),
                                  onOpenDetails: () =>
                                      context.push('/landmarks/${lm.id}'),
                                  onOpenAr: lm.isArReady
                                      ? () {
                                          Navigator.of(context).push(
                                            MaterialPageRoute(
                                              builder: (_) => ARViewScreen(
                                                landmarkId: lm.id,
                                                landmarkName: lm.name,
                                              ),
                                            ),
                                          );
                                        }
                                      : null,
                                ),
                              );
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _archivalFilterTab({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: Material(
        color: selected ? AppColors.primary : AppColors.background,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(2),
          side: BorderSide(
            color: selected ? AppColors.primary : AppColors.rule,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 5),
            child: Text(
              label,
              style: TextStyle(
                fontFamily: AppFonts.serif,
                fontSize: 13.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? AppColors.surface : AppColors.primary,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _eraChip({
    required String label,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(right: 6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.brass : Colors.transparent,
            border: Border.all(
              color: selected ? AppColors.brassInk : AppColors.divider,
              width: 0.8,
            ),
          ),
          child: Text(
            label.toUpperCase(),
            style: AppText.meta.copyWith(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: selected ? AppColors.inkDeep : AppColors.textMuted,
            ),
          ),
        ),
      ),
    );
  }
}

// Floating right-side map button in archival style
class _MapControlButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback? onTap;

  const _MapControlButton({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final bg = active ? AppColors.inkDeep : AppColors.surface.withValues(alpha: 0.95);
    final fg = active ? AppColors.brass : AppColors.primary;
    final border = active ? AppColors.brass : AppColors.rule;

    return Material(
      color: bg,
      elevation: 2,
      shadowColor: Colors.black26,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(2),
        side: BorderSide(color: border, width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: 56,
          height: 46,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: fg),
              const SizedBox(height: 2),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: AppFonts.sans,
                  fontSize: 7.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.6,
                  color: active ? AppColors.surface : AppColors.charcoal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransportModeMiniBar extends StatelessWidget {
  final TransportMode selectedMode;
  final ValueChanged<TransportMode> onSelect;

  const _TransportModeMiniBar({
    required this.selectedMode,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: Border.all(color: AppColors.rule),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: TransportMode.values.map((m) {
          final active = m == selectedMode;
          return GestureDetector(
            onTap: () => onSelect(m),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              color: active ? AppColors.primary : Colors.transparent,
              child: Row(
                children: [
                  Icon(
                    m.icon,
                    size: 13,
                    color: active ? AppColors.brass : AppColors.charcoal,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    m.label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: AppFonts.sans,
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      color: active ? AppColors.surface : AppColors.charcoal,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// Swipeable bottom landmark card
class _AtlasCarouselCard extends StatelessWidget {
  final Landmark landmark;
  final bool isSelected;
  final bool isCalculating;
  final double? distanceMetres;
  final TransportMode selectedMode;
  final VoidCallback onTapCard;
  final VoidCallback onTapModeToggle;
  final VoidCallback onNavigate;
  final VoidCallback onOpenDetails;
  final VoidCallback? onOpenAr;

  const _AtlasCarouselCard({
    required this.landmark,
    required this.isSelected,
    required this.isCalculating,
    required this.distanceMetres,
    required this.selectedMode,
    required this.onTapCard,
    required this.onTapModeToggle,
    required this.onNavigate,
    required this.onOpenDetails,
    this.onOpenAr,
  });

  String? get _distText {
    final d = distanceMetres;
    if (d == null) return null;
    if (d >= 1000) return '${(d / 1000).toStringAsFixed(1)} KM AWAY';
    return '${d.toStringAsFixed(0)} M AWAY';
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTapCard,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surface,
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.rule,
            width: isSelected ? 1.5 : 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.16),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        padding: const EdgeInsets.all(10),
        child: Column(
          children: [
            Expanded(
              child: Row(
                children: [
                  // Mounted archival photo
                  SizedBox(
                    width: 82,
                    height: double.infinity,
                    child: Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          ArchivalPhoto(
                            url: landmark.media.heroImage,
                            placeholderIcon: categoryIcon(landmark.category),
                          ),
                          if (landmark.isArReady)
                            const Positioned(
                              top: 4,
                              left: 4,
                              child: ArchivalStamp('3D'),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Row(
                          children: [
                            FolioLabel(landmark.id),
                            if (_distText != null) ...[
                              const Spacer(),
                              Text(
                                _distText!,
                                style: AppText.meta.copyWith(
                                  fontSize: 9,
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          landmark.name,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontFamily: AppFonts.serif,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                            height: 1.12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${(landmark.municipality?.name ?? 'Pangasinan').toUpperCase()}  •  ${(landmark.era ?? landmark.category).toUpperCase()}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppText.meta.copyWith(fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            // Action strip: Navigate + Mode | 3D/AR | Dossier
            SizedBox(
              height: 32,
              child: Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: ElevatedButton.icon(
                      onPressed: isCalculating ? null : onNavigate,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.surface,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      icon: Icon(
                        selectedMode.icon,
                        size: 14,
                        color: AppColors.brass,
                      ),
                      label: Text(
                        isCalculating ? 'ROUTING…' : 'NAVIGATE',
                        style: const TextStyle(
                          fontFamily: AppFonts.sans,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.0,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  InkWell(
                    onTap: onTapModeToggle,
                    child: Container(
                      width: 30,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.background,
                        border: Border.all(color: AppColors.rule),
                      ),
                      child: const Icon(
                        Icons.tune,
                        size: 14,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                  if (onOpenAr != null) ...[
                    const SizedBox(width: 6),
                    Expanded(
                      flex: 3,
                      child: OutlinedButton.icon(
                        onPressed: onOpenAr,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.inkDeep,
                          backgroundColor: AppColors.brass.withValues(alpha: 0.2),
                          side: const BorderSide(color: AppColors.brassInk),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        icon: const Icon(
                          Icons.view_in_ar_outlined,
                          size: 14,
                          color: AppColors.brassInk,
                        ),
                        label: const Text(
                          'AR',
                          style: TextStyle(
                            fontFamily: AppFonts.sans,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 6),
                  Expanded(
                    flex: 3,
                    child: OutlinedButton(
                      onPressed: onOpenDetails,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.rule),
                        padding: const EdgeInsets.symmetric(horizontal: 6),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                      child: const Text(
                        'DOSSIER',
                        style: TextStyle(
                          fontFamily: AppFonts.sans,
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// Live Navigation Panel in archival styling
class _LiveNavPanel extends StatelessWidget {
  final Landmark destination;
  final double? remainingMetres;
  final RouteResult? initialRoute;
  final bool autoCenter;
  final bool isRerouting;
  final TransportMode mode;
  final VoidCallback onRecenter;
  final VoidCallback onStop;

  const _LiveNavPanel({
    required this.destination,
    required this.remainingMetres,
    required this.initialRoute,
    required this.autoCenter,
    required this.isRerouting,
    required this.mode,
    required this.onRecenter,
    required this.onStop,
  });

  String get _distanceLabel {
    final m = remainingMetres ?? initialRoute?.distanceMetres;
    if (m == null) return ' ';
    if (m >= 1000) return '${(m / 1000).toStringAsFixed(1)} KM';
    return '${m.toStringAsFixed(0)} M';
  }

  String get _etaLabel {
    final m = remainingMetres ?? initialRoute?.distanceMetres;
    if (m == null) return ' ';
    final minutes = (m / (mode.speedMetresPerSec * 60)).ceil();
    if (minutes < 60) return '$minutes MIN';
    final h = minutes ~/ 60;
    final min = minutes % 60;
    return min == 0 ? '$h HR' : '$h HR $min MIN';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: Stack(
        children: [
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            left: 12,
            right: 12,
            child: EngravedFrame(
              fill: AppColors.inkDeep,
              color: AppColors.brass.withValues(alpha: 0.5),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              child: Row(
                children: [
                  Icon(mode.icon, color: AppColors.brass, size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: isRerouting
                        ? const Text(
                            'Recalculating route…',
                            style: TextStyle(
                              fontFamily: AppFonts.serif,
                              color: AppColors.surface,
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          )
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                destination.name,
                                style: const TextStyle(
                                  fontFamily: AppFonts.serif,
                                  color: AppColors.surface,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 17,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '$_distanceLabel  •  $_etaLabel',
                                style: AppText.meta.copyWith(
                                  color: AppColors.brass,
                                  fontSize: 10.5,
                                ),
                              ),
                            ],
                          ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 20,
            left: 14,
            right: 14,
            child: Row(
              children: [
                if (!autoCenter)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: Material(
                      color: AppColors.surface,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                        side: const BorderSide(color: AppColors.rule),
                      ),
                      child: InkWell(
                        onTap: onRecenter,
                        child: const SizedBox(
                          width: 46,
                          height: 46,
                          child: Icon(
                            Icons.my_location,
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ArDirectionScreen(
                            targetStop: destination,
                            stopNumber: 1,
                            totalStops: 1,
                            segmentPoints: initialRoute?.points ?? const [],
                          ),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.explore_outlined,
                      size: 18,
                      color: AppColors.brass,
                    ),
                    label: const Text(
                      'AR GUIDE',
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                        side: const BorderSide(
                          color: AppColors.brass,
                          width: 0.9,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: onStop,
                    icon: const Icon(Icons.close, size: 18),
                    label: const Text(
                      'END ROUTE',
                      style: TextStyle(
                        fontFamily: AppFonts.sans,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.2,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      foregroundColor: AppColors.surface,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ArProximityBanner extends StatelessWidget {
  final Landmark destination;
  final VoidCallback onViewAR;
  final VoidCallback onDismiss;

  const _ArProximityBanner({
    required this.destination,
    required this.onViewAR,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return EngravedFrame(
      fill: AppColors.inkDeep,
      color: AppColors.brass,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          const Icon(
            Icons.view_in_ar_outlined,
            color: AppColors.brass,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'LANDMARK WITHIN 50M',
                  style: AppText.eyebrow.copyWith(
                    color: AppColors.brass,
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  destination.name,
                  style: const TextStyle(
                    fontFamily: AppFonts.serif,
                    color: AppColors.surface,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: onViewAR,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.brass,
              foregroundColor: AppColors.inkDeep,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(2),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text(
              'OPEN AR',
              style: TextStyle(
                fontFamily: AppFonts.sans,
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.9,
              ),
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: onDismiss,
            child: const Icon(
              Icons.close,
              color: AppColors.surface,
              size: 18,
            ),
          ),
        ],
      ),
    );
  }
}
