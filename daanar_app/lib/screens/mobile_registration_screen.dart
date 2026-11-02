import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';

class MobileRegistrationScreen extends ConsumerStatefulWidget {
  final String? initialError;

  const MobileRegistrationScreen({super.key, this.initialError});

  @override
  ConsumerState<MobileRegistrationScreen> createState() =>
      _MobileRegistrationScreenState();
}

class _MobileRegistrationScreenState
    extends ConsumerState<MobileRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();

  bool _submitting = false;
  bool _otpStep = false;
  String? _errorText;
  String? _otpToken;
  String? _demoOtpCode;
  String? _normalizedPhone;

  Timer? _resendTimer;
  int _resendSeconds = 0;

  @override
  void initState() {
    super.initState();
    _errorText = widget.initialError;
  }

  @override
  void didUpdateWidget(covariant MobileRegistrationScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialError != null &&
        widget.initialError != oldWidget.initialError) {
      _errorText = widget.initialError;
      _otpStep = false;
    }
  }

  @override
  void dispose() {
    _resendTimer?.cancel();
    _phoneController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendCooldown() {
    _resendTimer?.cancel();
    setState(() => _resendSeconds = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendSeconds <= 1) {
        timer.cancel();
        setState(() => _resendSeconds = 0);
      } else {
        setState(() => _resendSeconds--);
      }
    });
  }

  String _extractErrorMessage(DioException e, String fallback) {
    final data = e.response?.data;
    if (data is Map<String, dynamic>) {
      final errors = data['errors'];
      if (errors is Map<String, dynamic> && errors.isNotEmpty) {
        final firstField = errors.values.first;
        if (firstField is List && firstField.isNotEmpty) {
          return firstField.first.toString();
        }
      }
      if (data['message'] is String) {
        return data['message'] as String;
      }
    }
    return fallback;
  }

  Future<void> _requestOtp() async {
    setState(() => _errorText = null);
    if (!_otpStep && !_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      final rawPhone = _phoneController.text.trim();
      final data = await ref.read(authServiceProvider).sendOtp(
            phoneNumber: rawPhone,
          );

      if (!mounted) return;
      setState(() {
        _otpStep = true;
        _normalizedPhone = (data['phone_number'] as String?) ??
            AuthService.normalizePhilippinePhone(rawPhone);
        _otpToken = data['otp_token'] as String?;
        _demoOtpCode = data['demo_otp']?.toString();
        _otpController.clear();
      });
      _startResendCooldown();
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _errorText = _extractErrorMessage(
            e,
            'Could not send verification code. Please check your mobile number.',
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Future<void> _verifyAndRegister() async {
    setState(() => _errorText = null);
    final code = _otpController.text.trim();

    if (code.length != 6) {
      setState(() {
        _errorText = 'Please enter the 6-digit verification code.';
      });
      return;
    }

    setState(() => _submitting = true);

    try {
      await ref.read(authServiceProvider).registerMobile(
            phoneNumber: _normalizedPhone ?? _phoneController.text.trim(),
            userRole: AppConstants.normalUserRole,
            otpCode: code,
            otpToken: _otpToken,
          );
      if (mounted) {
        context.go('/home');
      }
    } on DioException catch (e) {
      if (mounted) {
        setState(() {
          _errorText = _extractErrorMessage(
            e,
            'Invalid or expired verification code. Please try again.',
          );
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorText = e.toString());
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  void _autoFillDemoOtp() {
    if (_demoOtpCode == null) return;
    _otpController.text = _demoOtpCode!;
    _verifyAndRegister();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Column(
          children: [
            // Simulated SMS Notification Banner (shown when demo_otp is present)
            if (_otpStep && _demoOtpCode != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _submitting ? null : _autoFillDemoOtp,
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E242B),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.secondary.withValues(alpha: 0.65),
                          width: 1.2,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.35),
                            blurRadius: 14,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: AppColors.secondary.withValues(alpha: 0.18),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.sms_rounded,
                              color: AppColors.secondary,
                              size: 20,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Text(
                                      'MESSAGES • NOW',
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                        letterSpacing: 0.8,
                                        color: AppColors.secondary,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: const Text(
                                        'Tap to Auto-Fill',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.charcoal,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'DaanAR: Your verification code is $_demoOtpCode',
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),

            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 24,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Logo & Header
                        Center(
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: AppColors.secondary,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.25),
                                  blurRadius: 16,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/logo.png',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 18),
                        const Text(
                          'Welcome to DaanAR',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _otpStep
                              ? 'Enter the 6-digit verification code sent to your mobile number.'
                              : 'Verify your mobile number to explore Pangasinan’s heritage landmarks in 3D & AR.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withValues(alpha: 0.8),
                            height: 1.4,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Registration / OTP Card
                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.2),
                                blurRadius: 20,
                                offset: const Offset(0, 8),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!_otpStep) ...[
                                // STEP 1: MOBILE NUMBER INPUT
                                const Text(
                                  'Philippine Mobile Number',
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.charcoal,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextFormField(
                                  controller: _phoneController,
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.allow(
                                      RegExp(r'[0-9+\s-]'),
                                    ),
                                    LengthLimitingTextInputFormatter(16),
                                  ],
                                  decoration: InputDecoration(
                                    hintText: '0917 123 4567 or +639171234567',
                                    prefixIcon: const Icon(
                                      Icons.phone_android_rounded,
                                      color: AppColors.primary,
                                    ),
                                    filled: true,
                                    fillColor: AppColors.background,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                        width: 1.8,
                                      ),
                                    ),
                                  ),
                                  validator: (value) {
                                    final text = (value ?? '').trim();
                                    if (text.isEmpty) {
                                      return 'Please enter your mobile number.';
                                    }
                                    if (!AuthService.isValidPhilippinePhone(
                                      text,
                                    )) {
                                      return 'Enter a valid PH number (09XXXXXXXXX or +639XXXXXXXXX).';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 6),
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.lock_outline_rounded,
                                      size: 13,
                                      color: AppColors.textMuted,
                                    ),
                                    SizedBox(width: 4),
                                    Expanded(
                                      child: Text(
                                        'Your number is masked in visitor reports (+63 9XX *** XXXX).',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: AppColors.textMuted,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                // STEP 2: 6-DIGIT OTP VERIFICATION
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          const Text(
                                            '6-Digit Verification Code',
                                            style: TextStyle(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.charcoal,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            'Sent to ${_normalizedPhone ?? _phoneController.text}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppColors.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _submitting
                                          ? null
                                          : () {
                                              _resendTimer?.cancel();
                                              setState(() {
                                                _otpStep = false;
                                                _errorText = null;
                                                _demoOtpCode = null;
                                              });
                                            },
                                      child: const Text(
                                        'Change Number',
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                TextField(
                                  controller: _otpController,
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 10,
                                    color: AppColors.charcoal,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(6),
                                  ],
                                  decoration: InputDecoration(
                                    hintText: '••••••',
                                    hintStyle: TextStyle(
                                      fontSize: 22,
                                      letterSpacing: 10,
                                      color: AppColors.textMuted.withValues(
                                        alpha: 0.5,
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: AppColors.background,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppColors.primary,
                                        width: 1.8,
                                      ),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    if (value.length == 6 && !_submitting) {
                                      _verifyAndRegister();
                                    }
                                  },
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'Code expires in 5 minutes',
                                      style: TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.textMuted,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed:
                                          (_submitting || _resendSeconds > 0)
                                              ? null
                                              : _requestOtp,
                                      style: TextButton.styleFrom(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: Text(
                                        _resendSeconds > 0
                                            ? 'Resend in ${_resendSeconds}s'
                                            : 'Resend Code',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                          color: _resendSeconds > 0
                                              ? AppColors.textMuted
                                              : AppColors.primary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              if (_errorText != null) ...[
                                const SizedBox(height: 12),
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.red.shade50,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: Colors.red.shade200,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.error_outline,
                                        color: Colors.red.shade700,
                                        size: 18,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          _errorText!,
                                          style: TextStyle(
                                            color: Colors.red.shade800,
                                            fontSize: 12.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],

                              const SizedBox(height: 18),
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _submitting
                                      ? null
                                      : (_otpStep
                                          ? _verifyAndRegister
                                          : _requestOtp),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.secondary,
                                    foregroundColor: AppColors.charcoal,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  icon: _submitting
                                      ? const SizedBox(
                                          width: 18,
                                          height: 18,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            color: AppColors.charcoal,
                                          ),
                                        )
                                      : Icon(
                                          _otpStep
                                              ? Icons.verified_user_rounded
                                              : Icons.sms_outlined,
                                        ),
                                  label: Text(
                                    _submitting
                                        ? (_otpStep
                                            ? 'Verifying...'
                                            : 'Sending Code...')
                                        : (_otpStep
                                            ? 'Verify & Continue to DaanAR'
                                            : 'Send Verification Code'),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
