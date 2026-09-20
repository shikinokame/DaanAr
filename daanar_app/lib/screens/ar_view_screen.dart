import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/theme.dart';

/// Launches the WebAR experience in the device's native Chrome browser,
/// which properly handles getUserMedia (camera) permissions.
class ARViewScreen extends StatefulWidget {
  final int landmarkId;
  final String landmarkName;

  const ARViewScreen({
    super.key,
    required this.landmarkId,
    required this.landmarkName,
  });

  @override
  State<ARViewScreen> createState() => _ARViewScreenState();
}

class _ARViewScreenState extends State<ARViewScreen> {
  bool _launching = false;
  bool _permissionDenied = false;

  @override
  void initState() {
    super.initState();
    _checkAndLaunch();
  }

  Future<void> _checkAndLaunch() async {
    final status = await Permission.camera.request();
    if (!mounted) return;

    if (status.isDenied || status.isPermanentlyDenied) {
      setState(() => _permissionDenied = true);
      return;
    }

    await _launchAR();
  }

  Future<void> _launchAR() async {
    setState(() => _launching = true);

    final base = 'https://letdown-twiddle-thirty.ngrok-free.dev';
    final url = Uri.parse(
      '$base/ar/landmark/${widget.landmarkId}?ngrok-skip-browser-warning=true',
    );

    try {
      final launched = await launchUrl(
        url,
        mode: LaunchMode.externalApplication, // opens in Chrome
      );
      if (!launched && mounted) {
        _showError('Could not open Chrome. Please install Chrome and try again.');
      }
    } catch (e) {
      if (mounted) _showError(e.toString());
    } finally {
      if (mounted) setState(() => _launching = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.primary),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Back button ───────────────────────────────────────────────
            Positioned(
              top: 8,
              left: 8,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.secondary.withValues(alpha: 0.5)),
                  ),
                  child: const Icon(Icons.arrow_back, color: Colors.white, size: 22),
                ),
              ),
            ),

            // ── Main content ──────────────────────────────────────────────
            Center(
              child: _permissionDenied
                  ? _buildPermissionDenied()
                  : _buildLaunchUI(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLaunchUI() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // AR icon
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppColors.secondary.withValues(alpha: 0.15),
              border: Border.all(color: AppColors.secondary, width: 2),
            ),
            child: const Icon(Icons.view_in_ar_rounded, size: 52, color: AppColors.secondary),
          ),
          const SizedBox(height: 24),
          Text(
            widget.landmarkName,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'The AR experience will open in Chrome.\nAllow camera access when prompted.',
            style: TextStyle(color: Colors.white60, fontSize: 14, height: 1.6),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          if (_launching)
            const CircularProgressIndicator(color: AppColors.secondary)
          else
            ElevatedButton.icon(
              onPressed: _launchAR,
              icon: const Icon(Icons.open_in_browser),
              label: const Text(
                'Open AR in Chrome',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
                foregroundColor: AppColors.charcoal,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ),

          const SizedBox(height: 20),
          const Text(
            'Press Back in Chrome to return to the app.',
            style: TextStyle(color: Colors.white38, fontSize: 12),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDenied() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.no_photography, size: 72, color: AppColors.secondary),
          const SizedBox(height: 20),
          const Text(
            'Camera Permission Required',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          const Text(
            'DaanAR needs camera access for the AR experience. Please grant camera permission in your device settings.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 28),
          ElevatedButton.icon(
            onPressed: openAppSettings,
            icon: const Icon(Icons.settings),
            label: const Text('Open Settings'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.secondary,
              foregroundColor: AppColors.charcoal,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
        ],
      ),
    );
  }
}
