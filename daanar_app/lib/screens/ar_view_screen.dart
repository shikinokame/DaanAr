import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:webview_flutter/webview_flutter.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../services/landmark_service.dart';

/// Shows the 3D / AR landmark page inside the app (no Chrome redirect).
///
/// The page is rendered in an in-app WebView. When the user taps
/// "View in your Space (AR)", `<model-viewer>` asks to open Google Scene Viewer
/// through an `intent://` URL. We catch that URL and open Scene Viewer
/// natively (see MainActivity.kt). It shows on top of DaanAR, and pressing
/// Back returns straight to this screen.
class ARViewScreen extends ConsumerStatefulWidget {
  final int landmarkId;
  final String landmarkName;

  const ARViewScreen({
    super.key,
    required this.landmarkId,
    required this.landmarkName,
  });

  @override
  ConsumerState<ARViewScreen> createState() => _ARViewScreenState();
}

class _ARViewScreenState extends ConsumerState<ARViewScreen> {
  static const _arChannel = MethodChannel('ph.daanar/ar');

  late final WebViewController _controller;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    // Log virtual AR view (fire-and-forget)
    ref.read(landmarkServiceProvider).logAnalyticsEvent(
          landmarkId: widget.landmarkId,
          actionType: 'AR_VIEW',
          verificationMethod: 'REMOTE',
        );

    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(Colors.black)
      ..addJavaScriptChannel('DaanAR', onMessageReceived: (msg) {
        if (msg.message == 'close' && mounted) Navigator.of(context).maybePop();
      })
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _onNavigationRequest,
          onPageFinished: (_) async {
            // The page's own back button calls history.back(), which does
            // nothing in a WebView with no history, so route it to Flutter.
            await _controller.runJavaScript(
              "window.history.back = function(){ DaanAR.postMessage('close'); };",
            );
            if (mounted) setState(() => _loading = false);
          },
          onWebResourceError: (err) {
            if (err.isForMainFrame == false) return;
            if (mounted) {
              setState(() {
                _loading = false;
                _error = err.description;
              });
            }
          },
        ),
      );

    _load();
  }

  Uri get _arUrl {
    final serverBase = AppConstants.baseUrl
        .replaceAll('/api/v1', '')
        .replaceAll(RegExp(r'/$'), '');
    final cacheBust = DateTime.now().millisecondsSinceEpoch ~/ 60000;
    return Uri.parse(
      '$serverBase/ar/landmark/${widget.landmarkId}?ngrok-skip-browser-warning=true&v=$cacheBust',
    );
  }

  void _load() {
    setState(() {
      _loading = true;
      _error = null;
    });
    _controller.loadRequest(
      _arUrl,
      headers: const {'ngrok-skip-browser-warning': 'true'},
    );
  }

  Future<NavigationDecision> _onNavigationRequest(NavigationRequest req) async {
    final url = req.url;
    final isSceneViewer =
        url.startsWith('intent://arvr.google.com') ||
        url.startsWith('https://arvr.google.com/scene-viewer');

    if (isSceneViewer) {
      bool opened = false;
      try {
        opened = await _arChannel
                .invokeMethod<bool>('openSceneViewer', {'uri': url}) ??
            false;
      } on PlatformException {
        opened = false;
      }
      if (!opened && mounted) {
        _showError(
          'AR is not available on this device. Make sure "Google Play Services for AR" is installed and up to date.',
        );
      }
      return NavigationDecision.prevent;
    }

    // Block any other non-web scheme so the WebView never shows an error page.
    if (!url.startsWith('http')) return NavigationDecision.prevent;
    return NavigationDecision.navigate;
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
            if (_error == null) WebViewWidget(controller: _controller),
            if (_loading && _error == null)
              const Center(
                child: CircularProgressIndicator(color: AppColors.secondary),
              ),
            if (_error != null) Center(child: _buildError()),
          ],
        ),
      ),
    );
  }

  Widget _buildError() {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.cloud_off, size: 64, color: AppColors.secondary),
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
          const Text(
            'Could not load the AR experience. Check your connection and that the server is running.',
            style: TextStyle(color: Colors.white70, fontSize: 14, height: 1.5),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              OutlinedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Colors.white38),
                ),
                child: const Text('Back'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _load,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.secondary,
                  foregroundColor: AppColors.charcoal,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
