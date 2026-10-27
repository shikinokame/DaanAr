import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/theme.dart';
import '../core/token_storage.dart';
import '../services/auth_service.dart';
import '../widgets/archival.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnim;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    _fadeAnim = CurvedAnimation(parent: _controller, curve: Curves.easeIn);
    _scaleAnim = Tween<double>(begin: 0.92, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic),
    );

    _controller.forward();

    // Navigate to home (if registered & active) or mobile registration after 2.5s
    Future.delayed(const Duration(milliseconds: 2500), () async {
      final registered = await TokenStorage.hasMobileRegistration();
      if (!registered) {
        if (mounted) context.go('/register');
        return;
      }

      final status = await ref.read(authServiceProvider).verifyActiveSession();
      if (!mounted) return;

      if (status == 'blocked') {
        context.go('/register?blocked=1');
      } else if (status == 'unregistered') {
        context.go('/register');
      } else {
        context.go('/home');
      }
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.inkDeep,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.brass.withValues(alpha: 0.45),
                width: 1,
              ),
            ),
            padding: const EdgeInsets.all(5),
            child: Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.brass.withValues(alpha: 0.25),
                  width: 0.8,
                ),
              ),
              child: Center(
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: ScaleTransition(
                    scale: _scaleAnim,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(5),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: AppColors.brass.withValues(alpha: 0.55),
                              width: 1,
                            ),
                          ),
                          child: ClipOval(
                            child: Image.asset(
                              'assets/images/logo.png',
                              width: 112,
                              height: 112,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                        const SizedBox(height: 28),
                        Text(
                          'PANGASINAN HERITAGE GUIDE',
                          style: AppText.eyebrow.copyWith(
                            color: AppColors.brass,
                            fontSize: 10.5,
                            letterSpacing: 2.6,
                          ),
                        ),
                        const SizedBox(height: 8),
                        RichText(
                          text: const TextSpan(
                            style: TextStyle(
                              fontFamily: AppFonts.serif,
                              fontSize: 54,
                              height: 0.98,
                              fontWeight: FontWeight.w700,
                              color: AppColors.surface,
                            ),
                            children: [
                              TextSpan(text: 'Daan'),
                              TextSpan(
                                text: 'AR',
                                style: TextStyle(
                                  fontFamily: AppFonts.serif,
                                  fontStyle: FontStyle.italic,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.brass,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        const OrnamentDivider(
                          color: AppColors.brass,
                          width: 120,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Walk the paths of memory',
                          style: TextStyle(
                            fontFamily: AppFonts.serif,
                            fontSize: 16,
                            fontStyle: FontStyle.italic,
                            color: AppColors.surface.withValues(alpha: 0.86),
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 48),
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.8,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.brass.withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
