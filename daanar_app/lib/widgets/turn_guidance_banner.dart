import 'package:flutter/material.dart';
import '../core/theme.dart';
import '../models/route_result.dart';
import '../services/bearing_service.dart';
import '../services/navigation_guidance.dart';

/// Shared maneuver display for the map, trail map and camera guide.
class TurnGuidanceBanner extends StatelessWidget {
  final NavigationProgress? progress;
  final bool rerouting;
  final String? fallback;
  final RouteResult? route;
  final String? error;
  const TurnGuidanceBanner({
    super.key,
    this.progress,
    this.rerouting = false,
    this.fallback,
    this.route,
    this.error,
  });

  static IconData iconFor(RouteManeuver maneuver) => switch (maneuver) {
    RouteManeuver.left => Icons.turn_left_rounded,
    RouteManeuver.right => Icons.turn_right_rounded,
    RouteManeuver.slightLeft => Icons.turn_slight_left_rounded,
    RouteManeuver.slightRight => Icons.turn_slight_right_rounded,
    RouteManeuver.sharpLeft => Icons.turn_sharp_left_rounded,
    RouteManeuver.sharpRight => Icons.turn_sharp_right_rounded,
    RouteManeuver.uTurn => Icons.u_turn_left_rounded,
    RouteManeuver.roundabout => Icons.roundabout_right_rounded,
    RouteManeuver.arrive => Icons.flag_rounded,
    _ => Icons.straight_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final p = progress;
    final paused = rerouting || (p?.offRoute ?? false);
    final step = paused ? null : p?.step;
    final label = paused
        ? (rerouting ? 'Updating route' : 'Off route')
        : p == null
        ? 'Finding route'
        : step == null
        ? 'Follow the highlighted route'
        : p.distanceToTurn <= 12
        ? 'Now'
        : 'In ${BearingService.formatDistance(p.distanceToTurn)}';
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.inkDeep,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.brass.withValues(alpha: .6)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .18), blurRadius: 12),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                paused
                    ? Icons.alt_route_rounded
                    : iconFor(step?.direction ?? RouteManeuver.straight),
                color: AppColors.surface,
                size: 56,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: const TextStyle(
                        color: AppColors.brass,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      paused
                          ? (rerouting
                                ? 'Follow the map while the route updates'
                                : 'Return to the route or retry navigation')
                          : step?.instruction ??
                                fallback ??
                                'Waiting for GPS and road directions',
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.surface,
                        fontSize: 21,
                        height: 1.15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (!paused && p?.then != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  iconFor(p!.then!.direction),
                  color: AppColors.brass,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Then ${p.then!.instruction}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.surface,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (error != null) ...[
            const SizedBox(height: 8),
            Text(
              error!,
              style: const TextStyle(color: AppColors.brass, fontSize: 12),
            ),
          ],
          if (route?.provider == 'google') ...[
            const SizedBox(height: 8),
            Text(
              'Google Maps${route!.advisory == null ? '' : ' · ${route!.advisory}'}',
              style: const TextStyle(color: AppColors.surface, fontSize: 12),
            ),
            for (final warning in route!.warnings)
              Text(
                warning,
                style: const TextStyle(color: AppColors.surface, fontSize: 12),
              ),
          ],
        ],
      ),
    );
  }
}
