// lib/features/auth/presentation/otp_verification_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../app/app_routes.dart';
import '../../../shared/widgets/buttons/primary_button.dart';
import '../../../core/services/driver_service.dart';
import '../../../core/services/app_flow_resolver.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key});

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isLoading   = false;
  bool _isResending = false;
  String? _errorMessage;
  int _resendCountdown = 60;

  late String _phone;
  late String _verificationId;
  int? _resendToken;
  bool _isDriverLogin = false; // true  → returning driver login
                                // false → new signup

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final args =
        ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
    _phone          = args?['phone']          ?? '';
    _verificationId = args?['verificationId'] ?? '';
    _resendToken    = args?['resendToken'];
    _isDriverLogin  = args?['isDriverLogin']  as bool? ?? false;
    _startCountdown();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  // ── Countdown ──────────────────────────────────
  void _startCountdown() {
    setState(() => _resendCountdown = 60);
    Future.delayed(const Duration(seconds: 1), _tick);
  }

  void _tick() {
    if (!mounted) return;
    if (_resendCountdown > 0) {
      setState(() => _resendCountdown--);
      Future.delayed(const Duration(seconds: 1), _tick);
    }
  }

  // ── Resend OTP ─────────────────────────────────
  Future<void> _resendOtp() async {
    if (_resendCountdown > 0 || _isResending) return;

    setState(() {
      _isResending  = true;
      _errorMessage = null;
      for (final c in _controllers) {
        c.clear();
      }
    });
    _focusNodes[0].requestFocus();

    await FirebaseAuth.instance.verifyPhoneNumber(
      phoneNumber:          _phone,
      forceResendingToken:  _resendToken,
      codeSent: (verificationId, resendToken) {
        if (!mounted) return;
        setState(() {
          _verificationId = verificationId;
          _resendToken    = resendToken;
          _isResending    = false;
        });
        _startCountdown();
      },
      verificationCompleted: (_) {},
      verificationFailed: (e) {
        if (!mounted) return;
        setState(() {
          _isResending  = false;
          _errorMessage = 'Failed to resend. Please try again.';
        });
      },
      codeAutoRetrievalTimeout: (_) {},
      timeout: const Duration(seconds: 60),
    );
  }

  // ── Verify OTP ─────────────────────────────────
  Future<void> _verifyOtp() async {
    final otp = _controllers.map((c) => c.text).join();
    if (otp.length != 6) {
      setState(() =>
          _errorMessage = 'Please enter the complete 6-digit code.');
      return;
    }

    setState(() {
      _isLoading    = true;
      _errorMessage = null;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: _verificationId,
        smsCode:        otp,
      );

      final result =
          await FirebaseAuth.instance.signInWithCredential(credential);
      final uid = result.user!.uid;

      if (!mounted) return;

      if (_isDriverLogin) {
        // ── RETURNING DRIVER ───────────────────────
        // Use AppFlowResolver so routing logic is in one place.
        final destination =
            await AppFlowResolver.resolveDestination(uid);
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          destination.route,
          (_) => false,
          arguments: destination.arguments,
        );
      } else {
        // ── NEW SIGNUP ─────────────────────────────
        // Create driver doc (idempotent) → role selection.
        await DriverService.createDriverDocument(_phone);
        if (!mounted) return;
        Navigator.of(context).pushNamedAndRemoveUntil(
          AppRoutes.roleSelection,
          (_) => false,
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _isLoading    = false;
        _errorMessage = _friendlyError(e.code);
      });
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();
    } catch (e) {
      setState(() {
        _isLoading    = false;
        _errorMessage = 'Something went wrong. Please try again.';
      });
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'invalid-verification-code':
        return 'Incorrect code. Please check and try again.';
      case 'session-expired':
        return 'Code expired. Request a new one below.';
      case 'network-request-failed':
        return 'No internet connection. Check your network.';
      default:
        return 'Verification failed. Please try again.';
    }
  }

  // ── OTP digit box ──────────────────────────────
  Widget _buildOtpBox(int index) {
    return SizedBox(
      width: 48,
      height: 56,
      child: TextField(
        controller:        _controllers[index],
        focusNode:         _focusNodes[index],
        keyboardType:      TextInputType.number,
        textAlign:         TextAlign.center,
        style:             AppTextStyles.headingMedium.copyWith(fontSize: 22),
        maxLength:         1,
        inputFormatters:   [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          counterText: '',
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: AppColors.textSecondaryColor.withValues(alpha: 0.2),
              width: 1.5,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(
                color: AppColors.primaryColor, width: 2.5),
          ),
          errorBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Colors.red, width: 1.5),
          ),
          filled:    true,
          fillColor: _errorMessage != null
              ? Colors.red.withValues(alpha: 0.04)
              : AppColors.textSecondaryColor.withValues(alpha: 0.05),
        ),
        onChanged: (value) {
          setState(() => _errorMessage = null);
          if (value.length == 1 && index < 5) {
            _focusNodes[index + 1].requestFocus();
          }
          if (value.isEmpty && index > 0) {
            _focusNodes[index - 1].requestFocus();
          }
          if (index == 5 && value.length == 1) {
            _focusNodes[index].unfocus();
            _verifyOtp();
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new,
              size: 20, color: AppColors.textPrimaryColor),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 20),
            const Text('Verify Phone', style: AppTextStyles.headingMedium),
            const SizedBox(height: 12),
            RichText(
              text: TextSpan(
                text: 'We sent a 6-digit code to ',
                style: AppTextStyles.bodyMedium
                    .copyWith(color: AppColors.textSecondaryColor),
                children: [
                  TextSpan(
                    text: _phone,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color:      AppColors.textPrimaryColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 48),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, _buildOtpBox),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color:        Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.red.withValues(alpha: 0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(_errorMessage!,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: Colors.red)),
                    ),
                  ],
                ),
              ),
            ],

            const SizedBox(height: 40),

            PrimaryButton(
              label:     'Verify & Continue',
              onPressed: _isLoading ? null : _verifyOtp,
              isLoading: _isLoading,
            ),

            const SizedBox(height: 32),

            Center(
              child: Column(
                children: [
                  Text(
                    "Didn't receive a code?",
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondaryColor),
                  ),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: _resendCountdown == 0 && !_isResending
                        ? _resendOtp
                        : null,
                    child: _isResending
                        ? const SizedBox(
                            width:  16,
                            height: 16,
                            child:  CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(
                            _resendCountdown > 0
                                ? 'Resend in ${_resendCountdown}s'
                                : 'Resend New Code',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: _resendCountdown > 0
                                  ? AppColors.textDisabledColor
                                  : AppColors.primaryColor,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}