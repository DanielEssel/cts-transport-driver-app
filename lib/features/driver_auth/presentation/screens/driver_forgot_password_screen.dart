import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import 'driver_phone_screen.dart';
import '../../../driver_auth/presentation/widgets/driver_auth_widgets.dart';


/// Forgot password — 3 micro-steps on one screen using AnimatedSwitcher:
///   Step A: Enter phone number
///   Step B: Enter OTP
///   Step C: Set new password
/// Single screen with no back-stack pollution.
class DriverForgotPasswordScreen extends StatefulWidget {
  const DriverForgotPasswordScreen({super.key});

  @override
  State<DriverForgotPasswordScreen> createState() =>
      _DriverForgotPasswordScreenState();
}

class _DriverForgotPasswordScreenState
    extends State<DriverForgotPasswordScreen> {
  // 0 = phone, 1 = OTP, 2 = new password
  int _step = 0;
  bool _isLoading = false;

  // Step A
  final _phoneCtrl = TextEditingController();

  // Step B
  final List<TextEditingController> _otpCtrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _otpNodes =
      List.generate(6, (_) => FocusNode());
  int _resendSeconds = 30;

  // Step C
  final _newPassCtrl    = TextEditingController();
  final _confirmCtrl    = TextEditingController();
  bool _obscureNew      = true;
  bool _obscureConfirm  = true;

  @override
  void initState() {
    super.initState();
    _startResendTimer();
  }

  void _startResendTimer() {
    Future.delayed(const Duration(seconds: 1), () {
      if (!mounted) return;
      if (_resendSeconds > 0) {
        setState(() => _resendSeconds--);
        _startResendTimer();
      }
    });
  }

  @override
  void dispose() {
    _phoneCtrl.dispose();
    for (final c in _otpCtrls) c.dispose();
    for (final n in _otpNodes) n.dispose();
    _newPassCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (_step < 2) _step++;
    });
    // On step 1 (OTP shown), focus first box
    if (_step == 1) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _otpNodes[0].requestFocus());
    }
    // Step 2 complete → show success and pop
    if (_step == 2) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;
      _showSuccess();
    }
  }

  void _showSuccess() {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: const BoxDecoration(
                  color: AppColors.successLight, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: AppColors.success, size: 32),
            ),
            const SizedBox(height: 16),
            const Text('Password updated!',
                style: AppTextStyles.heading3),
            const SizedBox(height: 6),
            Text('You can now sign in with your new password.',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                textAlign: TextAlign.center),
            const SizedBox(height: 24),
            PrimaryBtn(
              label: 'Back to sign in',
              isLoading: false,
              enabled: true,
              onTap: () {
                Navigator.pop(context); // close sheet
                Navigator.pop(context); // close forgot password
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        leading: GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: AppColors.textPrimary),
          ),
        ),
        title: const Text('Reset password',
            style: AppTextStyles.heading4),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          children: [
            // Progress dots
            _ProgressDots(step: _step),
            const SizedBox(height: 28),

            // Animated step content
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, anim) => FadeTransition(
                  opacity: anim,
                  child: SlideTransition(
                    position: Tween<Offset>(
                      begin: const Offset(0.04, 0),
                      end: Offset.zero,
                    ).animate(anim),
                    child: child,
                  ),
                ),
                child: KeyedSubtree(
                  key: ValueKey(_step),
                  child: _stepContent(),
                ),
              ),
            ),

            PrimaryBtn(
              label: _step == 0
                  ? 'Send code'
                  : _step == 1
                      ? 'Verify'
                      : 'Update password',
              isLoading: _isLoading,
              enabled: _isStepValid,
              onTap: _next,
            ),
          ],
        ),
      ),
    );
  }

  bool get _isStepValid {
    if (_step == 0) return _phoneCtrl.text.trim().length >= 10;
    if (_step == 1) return _otpCtrls.every((c) => c.text.isNotEmpty);
    return _newPassCtrl.text.length >= 6 &&
        _newPassCtrl.text == _confirmCtrl.text;
  }

  Widget _stepContent() {
    switch (_step) {
      case 0:
        return _buildPhoneStep();
      case 1:
        return _buildOtpStep();
      default:
        return _buildNewPasswordStep();
    }
  }

  // ── Step A: Phone ──────────────────────────────────────────────────────────
  Widget _buildPhoneStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text("What's your\nphone number?",
            style: AppTextStyles.heading1),
        const SizedBox(height: 8),
        Text("We'll send a reset code to verify it's you.",
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 32),
        const Text('Phone number', style: AppTextStyles.labelLarge),
        const SizedBox(height: 10),
        TextFormField(
          controller: _phoneCtrl,
          keyboardType: TextInputType.phone,
          onChanged: (_) => setState(() {}),
          style: AppTextStyles.bodyMedium,
          decoration: _fieldDecoration(
              hint: '+233 XX XXX XXXX',
              icon: Icons.phone_rounded),
        ),
        const Spacer(),
      ],
    );
  }

  // ── Step B: OTP ────────────────────────────────────────────────────────────
  Widget _buildOtpStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Enter the\nverification code',
            style: AppTextStyles.heading1),
        const SizedBox(height: 8),
        RichText(
          text: TextSpan(
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary),
            children: [
              const TextSpan(text: 'Code sent to '),
              TextSpan(
                  text: _phoneCtrl.text,
                  style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary)),
            ],
          ),
        ),
        const SizedBox(height: 32),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(6, (i) {
            return SizedBox(
              width: 46,
              height: 54,
              child: TextFormField(
                controller: _otpCtrls[i],
                focusNode: _otpNodes[i],
                keyboardType: TextInputType.number,
                textAlign: TextAlign.center,
                maxLength: 1,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly
                ],
                onChanged: (v) {
                  if (v.isNotEmpty && i < 5) {
                    _otpNodes[i + 1].requestFocus();
                  }
                  setState(() {});
                },
                style: AppTextStyles.heading2,
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: _otpCtrls[i].text.isNotEmpty
                      ? AppColors.primary.withValues(alpha: 0.06)
                      : AppColors.surface,
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          const BorderSide(color: AppColors.border)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                      color: _otpCtrls[i].text.isNotEmpty
                          ? AppColors.primary
                          : AppColors.border,
                      width: _otpCtrls[i].text.isNotEmpty ? 1.5 : 0.5,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 2),
                  ),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 16),
        Center(
          child: _resendSeconds > 0
              ? Text('Resend in ${_resendSeconds}s',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary))
              : GestureDetector(
                  onTap: () =>
                      setState(() => _resendSeconds = 30),
                  child: Text('Resend code',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                      )),
                ),
        ),
        const Spacer(),
      ],
    );
  }

  // ── Step C: New password ───────────────────────────────────────────────────
  Widget _buildNewPasswordStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Set a new\npassword', style: AppTextStyles.heading1),
        const SizedBox(height: 8),
        Text('Choose something strong and memorable.',
            style: AppTextStyles.bodySmall
                .copyWith(color: AppColors.textSecondary)),
        const SizedBox(height: 32),
        const Text('New password', style: AppTextStyles.labelLarge),
        const SizedBox(height: 10),
        TextFormField(
          controller: _newPassCtrl,
          obscureText: _obscureNew,
          onChanged: (_) => setState(() {}),
          style: AppTextStyles.bodyMedium,
          decoration: _fieldDecoration(
            hint: 'Minimum 6 characters',
            icon: Icons.lock_rounded,
            suffix: GestureDetector(
              onTap: () =>
                  setState(() => _obscureNew = !_obscureNew),
              child: Icon(
                _obscureNew
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Confirm password', style: AppTextStyles.labelLarge),
        const SizedBox(height: 10),
        TextFormField(
          controller: _confirmCtrl,
          obscureText: _obscureConfirm,
          onChanged: (_) => setState(() {}),
          style: AppTextStyles.bodyMedium,
          decoration: _fieldDecoration(
            hint: 'Re-enter your password',
            icon: Icons.lock_outline_rounded,
            suffix: GestureDetector(
              onTap: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
              child: Icon(
                _obscureConfirm
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 18,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ),
        // Match indicator
        if (_confirmCtrl.text.isNotEmpty) ...[
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(
                _newPassCtrl.text == _confirmCtrl.text
                    ? Icons.check_circle_rounded
                    : Icons.cancel_rounded,
                size: 14,
                color: _newPassCtrl.text == _confirmCtrl.text
                    ? AppColors.success
                    : AppColors.error,
              ),
              const SizedBox(width: 5),
              Text(
                _newPassCtrl.text == _confirmCtrl.text
                    ? 'Passwords match'
                    : 'Passwords do not match',
                style: AppTextStyles.caption.copyWith(
                  color: _newPassCtrl.text == _confirmCtrl.text
                      ? AppColors.success
                      : AppColors.error,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
        const Spacer(),
      ],
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.bodySmall
          .copyWith(color: AppColors.textTertiary),
      prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
      suffixIcon: suffix,
      filled: true,
      fillColor: AppColors.surface,
      border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error)),
    );
  }
}

// ─── Progress dots ────────────────────────────────────────────────────────────
class _ProgressDots extends StatelessWidget {
  final int step;
  const _ProgressDots({required this.step});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final isActive = i == step;
        final isDone = i < step;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.only(right: 6),
          width: isActive ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: isDone || isActive
                ? AppColors.primary
                : AppColors.border,
            borderRadius: BorderRadius.circular(4),
          ),
        );
      }),
    );
  }
}