import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/theme.dart';
import '../models/landmark.dart';
import '../models/route_result.dart';
import '../services/location_service.dart';
import '../services/native_walking_navigation.dart';
import '../services/routing_service.dart';

/// Coordinates authenticated walking requests while Android owns the AR camera.
class ArDirectionScreen extends StatefulWidget {
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
  State<ArDirectionScreen> createState() => _ArDirectionScreenState();
}

class _ArDirectionScreenState extends State<ArDirectionScreen> {
  String? _error;
  bool _opening = false;
  bool _nativeOpen = false;
  LatLng get _destination =>
      LatLng(widget.targetStop.lat, widget.targetStop.lng);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _open());
  }

  Future<void> _open() async {
    if (!mounted || _opening) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      setState(
        () => _error =
            'Native AR walking guidance requires an ARCore-compatible Android phone. You can continue using the map.',
      );
      return;
    }
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      // Never turn a driving route or stale trail geometry into a pedestrian path.
      final fix = await LocationService.getCurrentPosition();
      if (!mounted) return;
      if (!fix.accuracy.isFinite || fix.accuracy > 40) {
        throw const FormatException(
          'GPS is too weak. Move to an open area and try again.',
        );
      }
      final route = await RoutingService.getRoute(
        origin: LatLng(fix.latitude, fix.longitude),
        destination: _destination,
      );
      if (!mounted) return;
      final payload = NativeWalkingNavigation.encodeRoute(route);
      NativeWalkingNavigation.channel.setMethodCallHandler((call) async {
        if (call.method != 'requestWalkingRoute' || !mounted || !_nativeOpen) {
          throw MissingPluginException('Walking navigation is closed');
        }
        final arguments = Map<Object?, Object?>.from(call.arguments as Map);
        try {
          final updated = await RoutingService.getRoute(
            origin: LatLng(
              (arguments['latitude'] as num).toDouble(),
              (arguments['longitude'] as num).toDouble(),
            ),
            destination: _destination,
          );
          return NativeWalkingNavigation.encodeRoute(updated);
        } on RoutingException catch (error) {
          throw PlatformException(
            code: 'ROUTE_UNAVAILABLE',
            message: error.message,
          );
        }
      });
      _nativeOpen = true;
      final result = await NativeWalkingNavigation.channel
          .invokeMapMethod<String, dynamic>('openWalkingNavigation', {
            'name': widget.targetStop.name,
            'route': payload,
          });
      _nativeOpen = false;
      if (!mounted) return;
      if (result?['arrived'] == true) widget.onMarkArrived?.call();
      if (mounted) Navigator.of(context).pop();
    } on RoutingException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on LocationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } on PlatformException catch (error) {
      if (mounted) {
        setState(
          () => _error =
              error.message ?? 'Could not start AR. Continue using the map.',
        );
      }
    } on FormatException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not prepare walking AR. Check GPS and internet, then retry.',
        );
      }
    } finally {
      _nativeOpen = false;
      NativeWalkingNavigation.channel.setMethodCallHandler(null);
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  void dispose() {
    NativeWalkingNavigation.channel.setMethodCallHandler(null);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.background,
    appBar: AppBar(title: const Text('Walking AR guide')),
    body: Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (_opening) const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(
              _error ??
                  'Preparing a fresh walking route for ${widget.targetStop.name}…',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (!_opening)
              FilledButton(onPressed: _open, child: const Text('Retry')),
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Back to map'),
            ),
          ],
        ),
      ),
    ),
  );
}
