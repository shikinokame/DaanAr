import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/theme.dart';
import '../models/landmark.dart';
import '../providers/landmark_providers.dart';
import '../services/landmark_service.dart';

/// Launches the Native Kotlin 3D Studio + Google ARCore Instant Placement
/// screen (`ArCoreLandmarkActivity.kt`) with 100% offline bundled `.glb`
/// support and automatic local caching for new admin uploads.
class ARViewScreen extends ConsumerStatefulWidget {
  final int landmarkId;
  final String landmarkName;
  final Landmark? landmark;

  const ARViewScreen({
    super.key,
    required this.landmarkId,
    required this.landmarkName,
    this.landmark,
  });

  @override
  ConsumerState<ARViewScreen> createState() => _ARViewScreenState();
}

class _ARViewScreenState extends ConsumerState<ARViewScreen> {
  static const _arChannel = MethodChannel('ph.daanar/ar');
  bool _launched = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    // Log virtual AR view (fire-and-forget, safe when offline)
    ref.read(landmarkServiceProvider).logAnalyticsEvent(
          landmarkId: widget.landmarkId,
          actionType: 'AR_VIEW',
          verificationMethod: 'REMOTE',
          landmark: widget.landmark,
        );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _launchNativeKotlinAr();
    });
  }

  Future<void> _launchNativeKotlinAr() async {
    if (_launched) return;
    _launched = true;

    Landmark? lm = widget.landmark;
    if (lm == null) {
      try {
        final detail = await ref.read(
          landmarkDetailProvider(widget.landmarkId).future,
        );
        lm = detail.landmark;
      } catch (_) {
        // Offline with no detail cache yet still works via bundled landmarkId map!
      }
    }

    try {
      await _arChannel.invokeMethod<bool>('openNativeArScreen', {
        'landmarkId': widget.landmarkId,
        'landmarkName': lm?.name ?? widget.landmarkName,
        'municipalityName': lm?.municipality?.name ?? 'Pangasinan',
        'category': lm?.category ?? 'Heritage',
        'description': (lm?.description.isNotEmpty == true)
            ? lm!.description
            : (lm?.shortDescription ?? ''),
        'modelUrl': lm?.media.arModelUrl ?? '',
      });

      if (mounted) {
        Navigator.of(context).maybePop();
      }
    } on PlatformException catch (e) {
      if (mounted) {
        setState(() {
          _error = e.message ?? 'Could not open Native AR screen.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1812),
      body: SafeArea(
        child: Center(
          child: _error != null
              ? Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.view_in_ar_rounded,
                        size: 64,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        widget.landmarkName,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _error!,
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white,
                          side: const BorderSide(color: Colors.white38),
                        ),
                        child: const Text('Back'),
                      ),
                    ],
                  ),
                )
              : const CircularProgressIndicator(color: AppColors.secondary),
        ),
      ),
    );
  }
}
