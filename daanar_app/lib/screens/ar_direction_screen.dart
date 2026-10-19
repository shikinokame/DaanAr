import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/theme.dart';
import '../models/landmark.dart';
import '../providers/location_provider.dart';
import '../services/bearing_service.dart';
import '../services/location_service.dart';
import 'ar_view_screen.dart';

/// Spatial HUD + Directional AR Wayfinder pointing toward [targetStop].
/// Works 100% offline using live GPS bearing + heading dial.
class ArDirectionScreen extends ConsumerStatefulWidget {
  final Landmark targetStop;
  final int stopNumber;
  final int totalStops;
  final String? nextInstruction;
  final VoidCallback? onMarkArrived;

  const ArDirectionScreen({
    super.key,
    required this.targetStop,
    required this.stopNumber,
    required this.totalStops,
    this.nextInstruction,
    this.onMarkArrived,
  });

  @override
  ConsumerState<ArDirectionScreen> createState() => _ArDirectionScreenState();
}

class _ArDirectionScreenState extends ConsumerState<ArDirectionScreen>
    with SingleTickerProviderStateMixin {
  StreamSubscription<dynamic>? _posSub;
  LatLng? _userPos;
  double _deviceHeading = 0.0;
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _initLocation();
  }

  Future<void> _initLocation() async {
    final locState = ref.read(locationProvider);
    if (locState is LocationReady) {
      _userPos = LatLng(
        locState.position.latitude,
        locState.position.longitude,
      );
      if (locState.position.heading.isFinite &&
          locState.position.heading > 0) {
        _deviceHeading = locState.position.heading;
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
          if (updated.position.heading.isFinite &&
              updated.position.heading > 0) {
            _deviceHeading = updated.position.heading;
          }
        });
      }
    }

    _posSub = LocationService.getPositionStream().listen((pos) {
      if (!mounted) return;
      setState(() {
        _userPos = LatLng(pos.latitude, pos.longitude);
        if (pos.heading.isFinite && pos.heading > 0) {
          _deviceHeading = pos.heading;
        }
      });
    });
  }

  @override
  void dispose() {
    _posSub?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final targetLatLng = LatLng(widget.targetStop.lat, widget.targetStop.lng);
    final origin = _userPos ??
        LatLng(
          widget.targetStop.lat - 0.0025,
          widget.targetStop.lng - 0.0018,
        );

    final distMetres = BearingService.distanceMetres(origin, targetLatLng);
    final targetBearing = BearingService.bearingBetween(origin, targetLatLng);
    final relAngle = BearingService.relativeAngle(
      targetBearing: targetBearing,
      deviceHeading: _deviceHeading,
    );
    final isLockedOn = relAngle.abs() <= 22.0;
    final cardinal = BearingService.cardinalWord(targetBearing);
    final prompt = BearingService.directionalPrompt(relAngle);

    return Scaffold(
      backgroundColor: const Color(0xFF0A140F),
      body: Stack(
        children: [
          // ── Spatial HUD Grid Background ─────────────────────────────────
          Positioned.fill(
            child: CustomPaint(
              painter: _SpatialHudGridPainter(isLockedOn: isLockedOn),
            ),
          ),

          // ── Top Navigation Bar ──────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.black54,
                          foregroundColor: Colors.white,
                        ),
                        icon: const Icon(Icons.arrow_back_rounded),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.65),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isLockedOn
                                  ? Colors.greenAccent
                                  : AppColors.secondary.withValues(alpha: 0.5),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'STOP ${widget.stopNumber} OF ${widget.totalStops} • AR WAYFINDER',
                                style: const TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                  color: AppColors.secondary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                widget.targetStop.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 14),

                  // ── Target Telemetry Pill ────────────────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: isLockedOn
                          ? Colors.green.shade900.withValues(alpha: 0.75)
                          : Colors.black.withValues(alpha: 0.6),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: isLockedOn
                            ? Colors.greenAccent
                            : Colors.white24,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          isLockedOn
                              ? Icons.gps_fixed_rounded
                              : Icons.explore_rounded,
                          size: 18,
                          color: isLockedOn
                              ? Colors.greenAccent
                              : AppColors.secondary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          isLockedOn
                              ? 'ALIGNED • HEADING ${cardinal.toUpperCase()}'
                              : '${prompt.toUpperCase()} • ${targetBearing.round()}° ($cardinal)',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.7,
                            color: isLockedOn
                                ? Colors.greenAccent
                                : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Center 3D Directional Arrow & Compass Ring ──────────────────
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final scale = 1.0 + (_pulseController.value * 0.05);
                    return Transform.scale(
                      scale: scale,
                      child: SizedBox(
                        width: 240,
                        height: 240,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            // Outer Compass Ring
                            Transform.rotate(
                              angle: -_deviceHeading * math.pi / 180.0,
                              child: CustomPaint(
                                size: const Size(240, 240),
                                painter: _CompassDialPainter(),
                              ),
                            ),

                            // Rotating 3D Wayfinder Arrow pointing to Landmark
                            Transform.rotate(
                              angle: relAngle * math.pi / 180.0,
                              child: Container(
                                width: 136,
                                height: 136,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: RadialGradient(
                                    colors: isLockedOn
                                        ? [
                                            Colors.greenAccent.withValues(
                                              alpha: 0.35,
                                            ),
                                            Colors.transparent,
                                          ]
                                        : [
                                            AppColors.secondary.withValues(
                                              alpha: 0.30,
                                            ),
                                            Colors.transparent,
                                          ],
                                  ),
                                  border: Border.all(
                                    color: isLockedOn
                                        ? Colors.greenAccent
                                        : AppColors.secondary,
                                    width: 2.2,
                                  ),
                                ),
                                child: Icon(
                                  Icons.navigation_rounded,
                                  size: 76,
                                  color: isLockedOn
                                      ? Colors.greenAccent
                                      : AppColors.secondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 20),

                // Distance & ETA Readout
                Text(
                  BearingService.formatDistance(distMetres),
                  style: const TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.nextInstruction ??
                      'Proceed $cardinal toward ${widget.targetStop.name}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ),

          // ── Bottom Controls (Heading Calibration + 3D AR Model Launch) ──
          Align(
            alignment: Alignment.bottomCenter,
            child: SafeArea(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFF14241C).withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.35),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(
                              Icons.compass_calibration_rounded,
                              size: 16,
                              color: AppColors.secondary,
                            ),
                            SizedBox(width: 6),
                            Text(
                              'Rotate / Calibrate Heading',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white70,
                              ),
                            ),
                          ],
                        ),
                        TextButton(
                          onPressed: () {
                            setState(() => _deviceHeading = targetBearing);
                          },
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text(
                            'Align to Target',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: AppColors.secondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _deviceHeading.clamp(0.0, 360.0),
                      min: 0.0,
                      max: 360.0,
                      activeColor: AppColors.secondary,
                      inactiveColor: Colors.white24,
                      onChanged: (val) => setState(() => _deviceHeading = val),
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ARViewScreen(
                                    landmarkId: widget.targetStop.id,
                                    landmarkName: widget.targetStop.name,
                                  ),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.secondary,
                              side: const BorderSide(
                                color: AppColors.secondary,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            icon: const Icon(Icons.view_in_ar_rounded, size: 18),
                            label: const Text(
                              '3D / AR Model',
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ),
                        ),
                        if (widget.onMarkArrived != null) ...[
                          const SizedBox(width: 10),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                widget.onMarkArrived?.call();
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.secondary,
                                foregroundColor: AppColors.charcoal,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              icon: const Icon(
                                Icons.check_circle_outline_rounded,
                                size: 18,
                              ),
                              label: const Text(
                                'Arrived Here',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SpatialHudGridPainter extends CustomPainter {
  final bool isLockedOn;
  const _SpatialHudGridPainter({required this.isLockedOn});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (isLockedOn ? Colors.greenAccent : AppColors.secondary)
          .withValues(alpha: 0.08)
      ..strokeWidth = 1.0;

    const spacing = 42.0;
    for (double x = 0; x < size.width; x += spacing) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += spacing) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _SpatialHudGridPainter oldDelegate) =>
      oldDelegate.isLockedOn != isLockedOn;
}

class _CompassDialPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 8;

    final ringPaint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawCircle(center, radius, ringPaint);

    final tickPaint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 1.5;

    for (int deg = 0; deg < 360; deg += 15) {
      final rad = (deg - 90) * math.pi / 180.0;
      final isMajor = deg % 90 == 0;
      final inner = radius - (isMajor ? 14 : 7);
      final p1 = Offset(
        center.dx + inner * math.cos(rad),
        center.dy + inner * math.sin(rad),
      );
      final p2 = Offset(
        center.dx + radius * math.cos(rad),
        center.dy + radius * math.sin(rad),
      );
      canvas.drawLine(p1, p2, tickPaint);
    }

    const labels = {0: 'N', 90: 'E', 180: 'S', 270: 'W'};
    labels.forEach((deg, text) {
      final rad = (deg - 90) * math.pi / 180.0;
      final pos = Offset(
        center.dx + (radius - 26) * math.cos(rad),
        center.dy + (radius - 26) * math.sin(rad),
      );
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: deg == 0 ? AppColors.secondary : Colors.white70,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
    });
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

