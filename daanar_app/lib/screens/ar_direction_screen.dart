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
import '../providers/location_provider.dart';
import '../services/bearing_service.dart';
import '../services/location_service.dart';
import '../services/routing_service.dart';

/// Live Camera AR Directional Wayfinder with 3D Red Extruded Ground Chevrons,
/// Green Corner Reticles, Top Destination/Distance Card, and Floating Mini-Map.
class ArDirectionScreen extends ConsumerStatefulWidget {
  final Landmark targetStop;
  final int stopNumber;
  final int totalStops;
  final String? nextInstruction;
  final List<LatLng> segmentPoints;
  final VoidCallback? onMarkArrived;

  const ArDirectionScreen({
    super.key,
    required this.targetStop,
    required this.stopNumber,
    required this.totalStops,
    this.nextInstruction,
    this.segmentPoints = const [],
    this.onMarkArrived,
  });

  @override
  ConsumerState<ArDirectionScreen> createState() => _ArDirectionScreenState();
}

class _ArDirectionScreenState extends ConsumerState<ArDirectionScreen>
    with SingleTickerProviderStateMixin {
  CameraController? _cameraController;
  bool _cameraInitialized = false;
  bool _cameraPermissionDenied = false;

  StreamSubscription<dynamic>? _posSub;
  StreamSubscription<CompassEvent>? _compassSub;

  LatLng? _userPos;
  double _compassHeading = 0.0;
  double _headingOffset = 0.0; // Optional manual fine-tuning offset
  bool _showCalibrationSlider = false;
  List<LatLng> _fetchedRoutePoints = const [];
  bool _isFetchingRoute = false;

  GoogleMapController? _miniMapController;
  late final AnimationController _flowController;

  @override
  void initState() {
    super.initState();
    _flowController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _initCamera();
    _initCompassAndGps();
  }

  Future<void> _initCamera() async {
    try {
      final status = await Permission.camera.request();
      if (!status.isGranted) {
        if (mounted) setState(() => _cameraPermissionDenied = true);
        return;
      }

      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _cameraPermissionDenied = true);
        return;
      }

      final backCam = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      final controller = CameraController(
        backCam,
        ResolutionPreset.high,
        enableAudio: false,
      );

      await controller.initialize();
      if (!mounted) {
        await controller.dispose();
        return;
      }

      setState(() {
        _cameraController = controller;
        _cameraInitialized = true;
        _cameraPermissionDenied = false;
      });
    } catch (_) {
      if (mounted) setState(() => _cameraPermissionDenied = true);
    }
  }

  Future<void> _initCompassAndGps() async {
    // 1. Real-time magnetometer compass stream
    _compassSub = FlutterCompass.events?.listen((event) {
      final heading = event.heading;
      if (heading != null && heading.isFinite && mounted) {
        setState(() {
          _compassHeading = (heading + 360.0) % 360.0;
        });
      }
    });

    // 2. Seed GPS from locationProvider or request fresh fix
    final locState = ref.read(locationProvider);
    if (locState is LocationReady) {
      _userPos = LatLng(
        locState.position.latitude,
        locState.position.longitude,
      );
      if (locState.position.heading.isFinite && locState.position.heading > 0) {
        _compassHeading = locState.position.heading;
      }
    } else {
      await ref.read(locationProvider.notifier).requestLocation();
      final updated = ref.read(locationProvider);
      if (updated is LocationReady && mounted) {
        setState(() {
          _userPos = LatLng(
            updated.position.latitude,
            updated.position.longitude,
          );
        });
      }
    }

    // 3. Continuous GPS stream
    _posSub = LocationService.getPositionStream().listen((pos) {
      if (!mounted) return;
      final nextPos = LatLng(pos.latitude, pos.longitude);
      setState(() {
        _userPos = nextPos;
      });
      _miniMapController?.animateCamera(CameraUpdate.newLatLng(nextPos));
      _ensureRoadRouteIfNeeded(nextPos);
    });

    if (_userPos != null) {
      _ensureRoadRouteIfNeeded(_userPos!);
    }
  }

  Future<void> _ensureRoadRouteIfNeeded(LatLng origin) async {
    if (widget.segmentPoints.length >= 2 ||
        _fetchedRoutePoints.length >= 2 ||
        _isFetchingRoute) {
      return;
    }
    _isFetchingRoute = true;
    try {
      final route = await RoutingService.getRoute(
        origin: origin,
        destination: LatLng(widget.targetStop.lat, widget.targetStop.lng),
      );
      if (mounted && route.points.length >= 2) {
        setState(() {
          _fetchedRoutePoints = route.points;
        });
      }
    } catch (_) {
      // Keep empty if offline
    } finally {
      _isFetchingRoute = false;
    }
  }

  /// Finds the next immediate waypoint along `segmentPoints` ahead of the user
  /// (at least ~12 metres ahead) so the ground chevrons follow the street path
  /// rather than pointing through buildings. Falls back to the stop coordinates.
  LatLng _nextPathTarget(LatLng user, LatLng finalStop) {
    final pts = widget.segmentPoints.length >= 2
        ? widget.segmentPoints
        : _fetchedRoutePoints;
    if (pts.length < 2) return finalStop;

    int closestIdx = 0;
    double closestDist = double.infinity;
    for (int i = 0; i < pts.length; i++) {
      final d = BearingService.distanceMetres(user, pts[i]);
      if (d < closestDist) {
        closestDist = d;
        closestIdx = i;
      }
    }

    // Look ahead along the polyline for a point at least 12m away
    for (int i = closestIdx + 1; i < pts.length; i++) {
      final d = BearingService.distanceMetres(user, pts[i]);
      if (d >= 12.0) {
        return pts[i];
      }
    }
    return finalStop;
  }

  @override
  void dispose() {
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

    final distMetres = _userPos != null
        ? BearingService.distanceMetres(userPos, stopPos)
        : 0.0;

    final immediateTarget = _nextPathTarget(userPos, stopPos);
    final targetBearing = BearingService.bearingBetween(
      userPos,
      immediateTarget,
    );

    final effectiveHeading = (_compassHeading + _headingOffset + 360.0) % 360.0;
    final relativeAngle = BearingService.relativeAngle(
      targetBearing: targetBearing,
      deviceHeading: effectiveHeading,
    );

    final activePolyline = widget.segmentPoints.length >= 2
        ? widget.segmentPoints
        : _fetchedRoutePoints;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── 1. Full-Screen Live Rear Camera Feed ──────────────────────────
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

          // ── 2. 3D Red Extruded Ground Chevrons on the Walkway ─────────────
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

          // ── 3. Neon Green Scanner Corner Brackets (⌜ ⌝ / ⌞ ⌟) ─────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 56, 18, 22),
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GreenCornerReticlePainter(),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),

          // ── 4. Top Navigation Controls + Frosted Destination/Distance Card ─
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

                  // Screenshot-style translucent Destination & Distance Card
                  Center(
                    child: Container(
                      constraints: const BoxConstraints(maxWidth: 340),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF262A2E).withValues(alpha: 0.72),
                        borderRadius: BorderRadius.circular(22),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.14),
                          width: 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.28),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.targetStop.name,
                            textAlign: TextAlign.center,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                              shadows: [
                                Shadow(
                                  color: Colors.black54,
                                  blurRadius: 6,
                                  offset: Offset(0, 2),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _userPos != null
                                ? BearingService.formatDistance(distMetres)
                                : 'Locating GPS...',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                          if (widget.nextInstruction != null &&
                              widget.nextInstruction!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              widget.nextInstruction!,
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
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
                              activeColor: const Color(0xFFEF2323),
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

          // ── 5. Floating Right-Side Mini-Map (matches screenshot) ──────────
          Positioned(
            top: MediaQuery.of(context).padding.top + 185,
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
                          color: const Color(0xFF2563EB),
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
          ? const Color(0xFFEF2323)
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

/// Draws the 4 neon-green corner brackets (`⌜ ⌝` / `⌞ ⌟`) from the screenshot.
class _GreenCornerReticlePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF34D399).withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.square;

    const double arm = 26.0;

    // Top-left
    canvas.drawPath(
      Path()
        ..moveTo(0, arm)
        ..lineTo(0, 0)
        ..lineTo(arm, 0),
      paint,
    );

    // Top-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - arm, 0)
        ..lineTo(size.width, 0)
        ..lineTo(size.width, arm),
      paint,
    );

    // Bottom-left
    canvas.drawPath(
      Path()
        ..moveTo(0, size.height - arm)
        ..lineTo(0, size.height)
        ..lineTo(arm, size.height),
      paint,
    );

    // Bottom-right
    canvas.drawPath(
      Path()
        ..moveTo(size.width - arm, size.height)
        ..lineTo(size.width, size.height)
        ..lineTo(size.width, size.height - arm),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Renders 3 stacked 3D extruded red ground chevrons (`^`) in perspective along
/// the walkway on the lower half of the camera preview, rotating smoothly toward
/// the next route waypoint.
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
      (
        yFactor: 0.45,
        scale: 0.46,
        extrudeDepth: 9.0,
        stepIndex: 2,
      ),
      // Middle chevron
      (
        yFactor: 0.51,
        scale: 0.68,
        extrudeDepth: 13.0,
        stepIndex: 1,
      ),
      // Nearest foreground chevron
      (
        yFactor: 0.61,
        scale: 1.00,
        extrudeDepth: 19.0,
        stepIndex: 0,
      ),
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
    final bottomLeft = Offset(-halfWidth + (bandThickness * 0.28), bandThickness * 0.65);
    final bottomRight = Offset(halfWidth - (bandThickness * 0.28), bandThickness * 0.65);

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

    // 2. Left 3D extruded front-facing vertical wall (darker crimson)
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
            ? const Color(0xFFB91C1C)
            : const Color(0xFF991B1B)
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
            ? const Color(0xFF991B1B)
            : const Color(0xFF7F1D1D)
        ..style = PaintingStyle.fill,
    );

    // 4. Left & right outer side end-caps
    final leftSideCap = Path()
      ..moveTo(topLeft.dx, topLeft.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy)
      ..lineTo(bottomLeft.dx, bottomLeft.dy + extrudeHeight)
      ..lineTo(topLeft.dx, topLeft.dy + extrudeHeight)
      ..close();
    canvas.drawPath(
      leftSideCap,
      Paint()..color = const Color(0xFF7F1D1D),
    );

    final rightSideCap = Path()
      ..moveTo(topRight.dx, topRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy)
      ..lineTo(bottomRight.dx, bottomRight.dy + extrudeHeight)
      ..lineTo(topRight.dx, topRight.dy + extrudeHeight)
      ..close();
    canvas.drawPath(
      rightSideCap,
      Paint()..color = const Color(0xFF6B1414),
    );

    // 5. Top bright red chevron surface
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
          ? const [Color(0xFFFF3B3B), Color(0xFFEF2323)]
          : const [Color(0xFFEF2323), Color(0xFFDC2626)],
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
