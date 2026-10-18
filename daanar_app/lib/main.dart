import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/router.dart';
import 'core/theme.dart';
import 'services/notification_service.dart';
import 'services/geofence_service.dart';
import 'services/location_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialise local notifications channel
  await NotificationService.instance.init();

  runApp(
    const ProviderScope(
      child: DaanArApp(),
    ),
  );
}

class DaanArApp extends ConsumerStatefulWidget {
  const DaanArApp({super.key});

  @override
  ConsumerState<DaanArApp> createState() => _DaanArAppState();
}

class _DaanArAppState extends ConsumerState<DaanArApp> {
  @override
  void initState() {
    super.initState();
    _startGeofencing();
  }

  Future<void> _startGeofencing() async {
    try {
      // Request location permission (if not already granted)
      await LocationService.getCurrentPosition();
      // Start watching position and alerting on landmark proximity
      await GeofenceService.instance.start(ref);
    } catch (_) {
      // If permission is denied, geofencing simply won't run — app still works
    }
  }

  @override
  void dispose() {
    GeofenceService.instance.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'DaanAR',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
