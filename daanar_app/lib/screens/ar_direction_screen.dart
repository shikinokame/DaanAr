import 'dart:async';
import 'dart:math' as math;
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import '../core/theme.dart';
import '../models/landmark.dart';
import '../models/route_result.dart';
import '../providers/location_provider.dart';
import '../services/bearing_service.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';
import '../services/navigation_guidance.dart';
import '../services/route_refresh_policy.dart';
import '../widgets/turn_guidance_banner.dart';

/// Walking maneuvers with approximate GPS/compass arrows and a live mini-map.
class ArDirectionScreen extends ConsumerStatefulWidget {
  final Landmark targetStop;
  final int stopNumber;
  final int totalStops;
  final String? nextInstruction;
  final List<LatLng> segmentPoints;
  final RouteResult? route;
  final VoidCallback? onMarkArrived;

  const ArDirectionScreen({
    super.key,
    required this.targetStop,
    required this.stopNumber,
    required this.totalStops,
    this.nextInstruction,
    this.segmentPoints = const [],
    this.route,
    this.onMarkArrived,
  });

  @override
  ConsumerState<ArDirectionScreen> createState() => _ArDirectionScreenState();
}

class _ArDirectionScreenState extends ConsumerState<ArDirectionScreen>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  CameraController? _cameraController;
  bool _cameraInitialized = false;
  bool _cameraPermissionDenied = false;
  int _cameraGeneration = 0;

  StreamSubscription<dynamic>? _posSub;
  StreamSubscription<CompassEvent>? _compassSub;

  LatLng? _userPos;
  double _compassHeading = 0.0;
  double _headingOffset = 0.0; // Optional manual fine-tuning offset
  bool _showCalibrationSlider = false;
  List<LatLng> _fetchedRoutePoints = const [];
  bool _isFetchingRoute = false;
  RouteResult? _route;
  NavigationGuidance? _guidance;
  NavigationProgress? _progress;
  RouteRefreshPolicy _refreshPolicy = RouteRefreshPolicy();
  double _gpsAccuracy = double.infinity;
  String? _routeError;
  bool _hasCompass = false;
  bool _accurateGps = false;
  String? _gpsError;

  GoogleMapController? _miniMapController;
  late final AnimationController _flowController;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _route = widget.route;
    if (_route != null) _guidance = NavigationGuidance(_route!);
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _initCamera();
    _initCompassAndGps();
  }

  Future<void> _initCamera() async {
    final generation = ++_cameraGeneration;
    CameraController? controller;
    try {
      final status = await Permission.camera.request();
      if (!mounted || generation != _cameraGeneration) return;
      if (!status.isGranted) {
        if (mounted) setState(() => _cameraPermissionDenied = true);
        return;
      }

      final cameras = await availableCameras();
      if (!mounted || generation != _cameraGeneration) return;
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraPermissionDenied = true);
        return;
      }

      final backCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        backCam,
        ResolutionPreset.medium,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted || generation != _cameraGeneration) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _cameraInitialized = true;
        _cameraPermissionDenied = false;
      });
    } catch (_) {
      await controller?.dispose();
      if (mounted && generation == _cameraGeneration) {
        setState(() => _cameraPermissionDenied = true);
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _cameraGeneration++;
      final camera = _cameraController;
      _cameraController = null;
      _cameraInitialized = false;
      camera?.dispose();
      _flowController.stop();
    } else if (state == AppLifecycleState.resumed) {
      _initCamera();
      _flowController.repeat();
    }
  }

  Future<void> _initCompassAndGps() async {
    // 1. Real-time magnetometer compass stream
    _compassSub = FlutterCompass.events?.listen(
      (event) {
        final heading = event.heading;
        if (heading != null && heading.isFinite && mounted) {
          setState(() {
            _compassHeading = (heading + 360.0) % 360.0;
            _hasCompass = true;
          });
        } else if (mounted) {
          setState(() => _hasCompass = false);
        }
      },
      onError: (_) {
        if (mounted) setState(() => _hasCompass = false);
      },
    );

    // 2. Seed GPS from locationProvider or request fresh fix
    final locState = ref.read(locationProvider);
    if (locState is LocationReady) {
      _userPos = LatLng(
        locState.position.latitude,
        locState.position.longitude,
      );
      _accurateGps = locState.position.accuracy <= 40;
      _gpsAccuracy = locState.position.accuracy;
      if (_route != null) {
        _refreshPolicy.recordAttempt(_userPos!, DateTime.now());
      }
      _progress = _guidance?.at(_userPos!);
    } else {
      await ref.read(locationProvider.notifier).requestLocation();
      if (!mounted) return;
      final updated = ref.read(locationProvider);
      if (updated is LocationReady && mounted) {
        setState(() {
          _userPos = LatLng(
            updated.position.latitude,
            updated.position.longitude,
          );
          _accurateGps = updated.position.accuracy <= 40;
          _gpsAccuracy = updated.position.accuracy;
          if (_route != null) {
            _refreshPolicy.recordAttempt(_userPos!, DateTime.now());
          }
          _progress = _guidance?.at(_userPos!);
        });
      }
    }

    if (!mounted) return;
    if (_userPos == null) {
      setState(() => _gpsError = 'Enable location to start walking guidance');
      return;
    }
    // 3. Continuous GPS stream
    _posSub = LocationService.getPositionStream().listen(
      (pos) {
        if (!mounted) return;
        final nextPos = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _userPos = nextPos;
          _accurateGps = pos.accuracy <= 40;
          _gpsAccuracy = pos.accuracy;
          _gpsError = null;
          _progress = _guidance?.at(nextPos, previousAlong: _progress?.along);
        });
        _miniMapController?.animateCamera(CameraUpdate.newLatLng(nextPos));
        _ensureRoadRouteIfNeeded(nextPos);
      },
      onError: (_) {
        if (mounted) {
          setState(() {
            _accurateGps = false;
            _gpsError = 'GPS unavailable - return to the map';
          });
        }
      },
    );

    if (_userPos != null) {
      _ensureRoadRouteIfNeeded(_userPos!);
    }
  }

  Future<void> _ensureRoadRouteIfNeeded(LatLng origin) async {
    if (!_accurateGps ||
        _isFetchingRoute ||
        !_refreshPolicy.shouldRefresh(
          position: origin,
          destination: LatLng(widget.targetStop.lat, widget.targetStop.lng),
          accuracy: _gpsAccuracy,
          progress: _progress,
          now: DateTime.now(),
        )) {
      return;
    }
    _refreshPolicy.recordAttempt(origin, DateTime.now());
    setState(() {
      _isFetchingRoute = true;
      _routeError = null;
    });
    try {
      final route = await RoutingService.getRoute(
        origin: origin,
        destination: LatLng(widget.targetStop.lat, widget.targetStop.lng),
      );
      if (mounted && route.points.length >= 2) {
        setState(() {
          _fetchedRoutePoints = route.points;
          _route = route;
          _guidance = NavigationGuidance(route);
          _progress = _guidance!.at(_userPos ?? origin);
        });
      }
    } on RoutingException catch (e) {
      if (mounted) setState(() => _routeError = e.message);
    } finally {
      if (mounted) setState(() => _isFetchingRoute = false);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cameraGeneration++;
    _posSub?.cancel();
    _compassSub?.cancel();
    _miniMapController?.dispose();
    _cameraController?.dispose();
    _flowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final stopPos = LatLng(widget.targetStop.lat, widget.targetStop.lng);
    final userPos = _userPos ?? stopPos;

    final distMetres = _progress?.remaining ?? 0.0;

    final immediateTarget = _progress?.lookAhead ?? userPos;
    final targetBearing = BearingService.bearingBetween(
      userPos,
      immediateTarget,
    );

    final effectiveHeading = (_compassHeading + _headingOffset + 360.0) % 360.0;
    final relativeAngle = BearingService.relativeAngle(
      targetBearing: targetBearing,
      deviceHeading: effectiveHeading,
    );

    final activePolyline =
        _guidance?.remainingPoints(_accurateGps ? _progress : null) ??
        (_fetchedRoutePoints.length >= 2
            ? _fetchedRoutePoints
            : widget.segmentPoints);
    final showArrows =
        _userPos != null &&
        _accurateGps &&
        _hasCompass &&
        _progress != null &&
        !_progress!.offRoute &&
        relativeAngle.abs() <= 75;
    final status =
        _gpsError ??
        (!_accurateGps
            ? 'Waiting for accurate GPS'
            : !_hasCompass
            ? 'Compass unavailable - use the map'
            : _progress?.offRoute == true
            ? 'Off route - follow the map'
            : _route == null
            ? 'Road directions unavailable - return to map'
            : !showArrows
            ? 'Turn your phone to face the route'
            : 'GPS guidance - approximate arrows');

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Full-Screen Live Rear Camera Feed
          _buildCameraLayer(),

          // Subtle bottom vignette so ground chevrons pop clearly on bright pavement
          IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.black.withValues(alpha: 0.28),
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withValues(alpha: 0.35),
                  ],
                  stops: const [0.0, 0.22, 0.65, 1.0],
                ),
              ),
            ),
          ),

          // Gold GPS/compass arrows; hide when location or alignment is unreliable.
          if (showArrows)
            Positioned.fill(
              child: IgnorePointer(
                child: AnimatedBuilder(
                  animation: _flowController,
                  builder: (context, _) {
                    return CustomPaint(
                      painter: _GroundChevronsPainter(
                        relativeAngleDegrees: relativeAngle,
                        pulseProgress: _flowController.value,
                      ),
                    );
                  },
                ),
              ),
            ),

          // 4. Top Navigation Controls + Frosted Destination/Distance Card
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top row: Back button + optional compass fine-tune toggle
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _CircleIconButton(
                        icon: Icons.arrow_back_rounded,
                        tooltip: 'Back to Trail Map',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                      _CircleIconButton(
                        icon: Icons.explore_outlined,
                        tooltip: 'Calibrate Compass Offset',
                        active: _showCalibrationSlider,
                        onTap: () => setState(
                          () =>
                              _showCalibrationSlider = !_showCalibrationSlider,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  TurnGuidanceBanner(
                    progress: _accurateGps ? _progress : null,
                    rerouting: _isFetchingRoute,
                    route: _route,
                    error: _routeError,
                    fallback:
                        _gpsError ??
                        (_route == null && !_isFetchingRoute
                            ? 'No road directions. Return to map or retry.'
                            : null),
                  ),

                  // Optional compact compass trim slider (hidden unless tapped)
                  if (_showCalibrationSlider) ...[
                    const SizedBox(height: 8),
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 20),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.tune_rounded,
                            color: Colors.white70,
                            size: 16,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Align Arrow',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Expanded(
                            child: Slider(
                              value: _headingOffset,
                              min: -180.0,
                              max: 180.0,
                              activeColor: const Color(0xFFD4A853),
                              inactiveColor: Colors.white24,
                              onChanged: (v) =>
                                  setState(() => _headingOffset = v),
                            ),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _headingOffset = 0.0),
                            style: TextButton.styleFrom(
                              minimumSize: Size.zero,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                            ),
                            child: const Text(
                              'Reset',
                              style: TextStyle(
                                color: AppColors.secondary,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // 5. Floating Right-Side Mini-Map (matches screenshot)
          if (MediaQuery.sizeOf(context).height >= 700 &&
              !_showCalibrationSlider)
            Positioned(
              bottom: MediaQuery.of(context).padding.bottom + 230,
              right: 18,
              child: Container(
                width: 122,
                height: 128,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.85),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Stack(
                  children: [
                    GoogleMap(
                      initialCameraPosition: CameraPosition(
                        target: userPos,
                        zoom: 16.5,
                      ),
                      onMapCreated: (c) => _miniMapController = c,
                      myLocationEnabled: true,
                      myLocationButtonEnabled: false,
                      zoomControlsEnabled: false,
                      mapToolbarEnabled: false,
                      compassEnabled: false,
                      rotateGesturesEnabled: false,
                      scrollGesturesEnabled: false,
                      zoomGesturesEnabled: false,
                      tiltGesturesEnabled: false,
                      markers: {
                        Marker(
                          markerId: const MarkerId('ar_mini_target'),
                          position: stopPos,
                          icon: BitmapDescriptor.defaultMarkerWithHue(
                            BitmapDescriptor.hueRed,
                          ),
                        ),
                      },
                      polylines: {
                        if (activePolyline.length >= 2)
                          Polyline(
                            polylineId: const PolylineId('ar_mini_route'),
                            points: activePolyline,
                            color: AppColors.brass,
                            width: 5,
                          ),
                      },
                    ),
                    // Tap mini-map to return to full map view
                    Positioned.fill(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: () => Navigator.of(context).pop(),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Positioned(
            bottom: MediaQuery.paddingOf(context).bottom + 12,
            left: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.inkDeep,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: AppColors.brass),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.targetStop.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.surface,
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _progress == null
                        ? 'Waiting for road directions'
                        : '${_progress!.etaLabel} - ${BearingService.formatDistance(distMetres)} remaining',
                    style: const TextStyle(
                      color: AppColors.surface,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    status,
                    style: const TextStyle(
                      color: AppColors.brass,
                      fontSize: 12,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () => Navigator.pop(context),
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.brass,
                            foregroundColor: AppColors.inkDeep,
                          ),
                          icon: const Icon(Icons.map_outlined),
                          label: const Text('Back to map'),
                        ),
                      ),
                      if (_route == null &&
                          !_isFetchingRoute &&
                          _userPos != null) ...[
                        const SizedBox(width: 8),
                        IconButton(
                          onPressed: () {
                            _refreshPolicy = RouteRefreshPolicy();
                            _ensureRoadRouteIfNeeded(_userPos!);
                          },
                          tooltip: 'Retry road directions',
                          icon: const Icon(
                            Icons.refresh,
                            color: AppColors.brass,
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCameraLayer() {
    if (_cameraInitialized && _cameraController != null) {
      final previewSize = _cameraController!.value.previewSize;
      if (previewSize != null) {
        return SizedBox.expand(
          child: FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: previewSize.height,
              height: previewSize.width,
              child: CameraPreview(_cameraController!),
            ),
          ),
        );
      }
      return CameraPreview(_cameraController!);
    }

    if (_cameraPermissionDenied) {
      return Container(
        color: const Color(0xFF14181F),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_outlined,
              color: Colors.white54,
              size: 46,
            ),
            const SizedBox(height: 12),
            const Text(
              'Camera access is required for live AR walkway view.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: 13.5),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: _initCamera,
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white38),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Enable Camera'),
            ),
          ],
        ),
      );
    }

    return const ColoredBox(color: Colors.black);
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;

  const _CircleIconButton({
    required this.icon,
    required this.tooltip,
    this.active = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? const Color(0xFFD4A853)
          : Colors.black.withValues(alpha: 0.48),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Tooltip(
          message: tooltip,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
        ),
      ),
    );
  }
}

class _GroundChevronsPainter extends CustomPainter {
  final double relativeAngleDegrees;
  final double pulseProgress;

  _GroundChevronsPainter({
    required this.relativeAngleDegrees,
    required this.pulseProgress,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Clamp horizontal path curvature so chevrons stay visible on screen while
    // clearly turning left or right when the route/compass turns.
    final clampedAngle = relativeAngleDegrees.clamp(-65.0, 65.0);
    final angleRad = clampedAngle * math.pi / 180.0;

    // 3 ground chevrons from furthest (index 2) to closest (index 0), drawn
    // back-to-front so nearer chevrons naturally overlap if angled.
    const chevronRows = [
      // Furthest chevron up the walkway
      (yFactor: 0.45, scale: 0.46, extrudeDepth: 9.0, stepIndex: 2),
      // Middle chevron
      (yFactor: 0.51, scale: 0.68, extrudeDepth: 13.0, stepIndex: 1),
      // Nearest foreground chevron
      (yFactor: 0.61, scale: 1.00, extrudeDepth: 19.0, stepIndex: 0),
    ];

    for (final row in chevronRows) {
      // Distance ahead along the ground plane shifts horizontally when turning
      final depthAhead = (0.68 - row.yFactor) * size.height;
      final centerX =
          (size.width * 0.47) + math.sin(angleRad) * (depthAhead * 0.95);
      final centerY = size.height * row.yFactor;

      // Subtle sequential highlight wave flowing forward from chevron 0 → 1 → 2
      final wavePhase = ((pulseProgress * 3.0) - row.stepIndex) % 3.0;
      final isHighlighted = wavePhase >= 0.0 && wavePhase < 1.1;

      canvas.save();
      canvas.translate(centerX, centerY);
      // Perspective yaw rotation on the ground plane
      canvas.rotate(angleRad * 0.55);

      _drawExtruded3DChevron(
        canvas: canvas,
        halfWidth: size.width * 0.36 * row.scale,
        chevronRise: 18.0 * row.scale,
        bandThickness: 20.0 * row.scale,
        extrudeHeight: row.extrudeDepth,
        isHighlighted: isHighlighted,
      );

      canvas.restore();
    }
  }

  void _drawExtruded3DChevron({
    required Canvas canvas,
    required double halfWidth,
    required double chevronRise,
    required double bandThickness,
    required double extrudeHeight,
    required bool isHighlighted,
  }) {
    // Key vertices of the flat-perspective chevron on the pavement:
    // Outer/back edge (points forward up the walkway):
    final topApex = Offset(0, -chevronRise - bandThickness);
    final topLeft = Offset(-halfWidth, -bandThickness * 0.35);
    final topRight = Offset(halfWidth, -bandThickness * 0.35);

    // Inner/front edge (facing the user):
    final innerApex = Offset(0, -chevronRise);
    final bottomLeft = Offset(
      -halfWidth + (bandThickness * 0.28),
      bandThickness * 0.65,
    );
    final bottomRight = Offset(
      halfWidth - (bandThickness * 0.28),
      bandThickness * 0.65,
    );

    // 1. Soft ground shadow underneath the 3D chevron block
    final shadowPath = Path()
      ..moveTo(topLeft.dx, topLeft.dy + extrudeHeight + 5)
      ..lineTo(topApex.dx, topApex.dy + extrudeHeight + 5)
      ..lineTo(topRight.dx, topRight.dy + extrudeHeight + 5)
      ..lineTo(bottomRight.dx, bottomRight.dy + extrudeHeight + 7)
      ..lineTo(innerApex.dx, innerApex.dy + extrudeHeight + 7)
      ..lineTo(bottomLeft.dx, bottomLeft.dy + extrudeHeight + 7)
      ..close();

    canvas.drawPath(
      shadowPath,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.32)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 7),
    );

    // 2. Left 3D extruded front-facing vertical wall (darker brass)
    final leftFrontWall = Path()
      ..moveTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(innerApex.dx, innerApex.dy)
      ..lineTo(innerApex.dx, innerApex.dy + extrudeHeight)
      ..lineTo(bottomLeft.dx, bottomLeft.dy + extrudeHeight)
      ..close();

    canvas.drawPath(
      leftFrontWall,
      Paint()
        ..color = isHighlighted
            ? const Color(0xFF9B732D)
            : const Color(0xFF7A5C22)
        ..style = PaintingStyle.fill,
    );

    // 3. Right 3D extruded front-facing vertical wall (slightly deeper shade for 3D lighting)
    final rightFrontWall = Path()
      ..moveTo(innerApex.dx, innerApex.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy + extrudeHeight)
      ..lineTo(innerApex.dx, innerApex.dy + extrudeHeight)
      ..close();

    canvas.drawPath(
      rightFrontWall,
      Paint()
        ..color = isHighlighted
            ? const Color(0xFF7A5C22)
            : const Color(0xFF624A1B)
        ..style = PaintingStyle.fill,
    );

    // 4. Left & right outer side end-caps
    final leftSideCap = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy + extrudeHeight)
      ..lineTo(topLeft.dx, topLeft.dy + extrudeHeight)
      ..close();
    canvas.drawPath(leftSideCap, Paint()..color = const Color(0xFF624A1B));

    final rightSideCap = Path()
      ..moveTo(topRight.dx, topRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy + extrudeHeight)
      ..lineTo(topRight.dx, topRight.dy + extrudeHeight)
      ..close();
    canvas.drawPath(rightSideCap, Paint()..color = const Color(0xFF493813));

    // 5. Top gold chevron surface
    final topFace = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(topApex.dx, topApex.dy)
      ..lineTo(topRight.dx, topRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(innerApex.dx, innerApex.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..close();

    final topGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: isHighlighted
          ? const [Color(0xFFEAC97A), Color(0xFFD4A853)]
          : const [Color(0xFFD4A853), Color(0xFFBE9444)],
    );

    canvas.drawPath(
      topFace,
      Paint()
        ..shader = topGradient.createShader(
          Rect.fromLTWH(
            -halfWidth,
            -chevronRise - bandThickness,
            halfWidth * 2,
            chevronRise + bandThickness * 2,
          ),
        )
        ..style = PaintingStyle.fill,
    );

    // Crisp subtle top-edge highlight line so the 3D bevel reads sharply
    canvas.drawPath(
      Path()
        ..moveTo(bottomLeft.dx, bottomLeft.dy)
        ..lineTo(innerApex.dx, innerApex.dy)
        ..lineTo(bottomRight.dx, bottomRight.dy),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant _GroundChevronsPainter oldDelegate) {
    return oldDelegate.relativeAngleDegrees != relativeAngleDegrees ||
        oldDelegate.pulseProgress != pulseProgress;
  }
}
