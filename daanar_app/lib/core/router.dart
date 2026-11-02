import 'package:go_router/go_router.dart';
import '../screens/splash_screen.dart';
import '../screens/mobile_registration_screen.dart';
import '../screens/shell_screen.dart';
import '../screens/home_screen.dart';
import '../screens/trails_screen.dart';
import '../screens/map_screen.dart';
import '../screens/landmark_detail_screen.dart';
import '../screens/trail_detail_screen.dart';
import '../screens/trail_navigation_screen.dart';

final appRouter = GoRouter(
  initialLocation: '/splash',
  routes: [
    GoRoute(
      path: '/splash',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/register',
      builder: (context, state) => MobileRegistrationScreen(
        initialError: state.uri.queryParameters['blocked'] == '1'
            ? 'This mobile number has been blocked by an administrator.'
            : null,
      ),
    ),

    // Shell with bottom nav (Home | Trails | Map)
    ShellRoute(
      builder: (context, state, child) => ShellScreen(child: child),
      routes: [
        GoRoute(
          path: '/home',
          builder: (context, state) => const HomeScreen(),
        ),
        GoRoute(
          path: '/trails',
          builder: (context, state) => const TrailsScreen(),
        ),
        GoRoute(
          path: '/map',
          builder: (context, state) => const MapScreen(),
        ),
      ],
    ),

    // Trail detail & live GPS + AR directional navigation outside shell (full screen)
    GoRoute(
      path: '/trails/:id',
      builder: (context, state) => TrailDetailScreen(
        trailId: int.parse(state.pathParameters['id']!),
      ),
    ),
    GoRoute(
      path: '/trails/:id/navigate',
      builder: (context, state) => TrailNavigationScreen(
        trailId: int.parse(state.pathParameters['id']!),
      ),
    ),

    // Landmark detail outside shell (full screen)
    GoRoute(
      path: '/landmarks/:id',
      builder: (context, state) => LandmarkDetailScreen(
        id: int.parse(state.pathParameters['id']!),
      ),
    ),
  ],
);
