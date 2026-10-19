import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../core/constants.dart';
import '../core/theme.dart';
import '../services/auth_service.dart';

class MobileRegistrationScreen extends ConsumerStatefulWidget {
  const MobileRegistrationScreen({super.key});

  @override
  ConsumerState<MobileRegistrationScreen> createState() =>
      _MobileRegistrationScreenState();
}

class _MobileRegistrationScreenState
    extends ConsumerState<MobileRegistrationScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  bool _submitting = false;
  String? _errorText;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _errorText = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _submitting = true);

    try {
      await ref.read(authServiceProvider).registerMobile(
            phoneNumber: _phoneController.text.trim(),
            userRole: AppConstants.normalUserRole,
          );
      if (mounted) {
        context.go('/home');
      }
    } on DioException catch (e) {
      final msg = (e.response?.data is Map<String, dynamic>)
          ? ((e.response?.data['message'] as String?) ??
              'Registration failed. Please check your mobile number.')
          : 'Registration failed. Please try again.';
      if (mounted) {
        setState(() => _errorText = msg);
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
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
                    'Register your mobile number to explore Pangasinan’s heritage landmarks in 3D & AR.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Registration Card
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
                            if (!AuthService.isValidPhilippinePhone(text)) {
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

                        const SizedBox(height: 12),

                        if (_errorText != null) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.red.shade200),
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

                        const SizedBox(height: 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            onPressed: _submitting ? null : _submit,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.secondary,
                              foregroundColor: AppColors.charcoal,
                              padding: const EdgeInsets.symmetric(vertical: 16),
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
                                : const Icon(Icons.arrow_forward_rounded),
                            label: Text(
                              _submitting
                                  ? 'Registering...'
                                  : 'Continue to DaanAR',
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
    );
  }
}
