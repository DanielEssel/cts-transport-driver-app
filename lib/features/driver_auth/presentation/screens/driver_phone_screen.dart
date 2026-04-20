import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../app/app_routes.dart';


/// Screen 1 of 3 — Phone number entry.
/// Immediately sends OTP on submit. Pushes to OTP verification.
class DriverPhoneScreen extends StatefulWidget {
  const DriverPhoneScreen({super.key});

  @override
  State<DriverPhoneScreen> createState() => _DriverPhoneScreenState();
}

class _DriverPhoneScreenState extends State<DriverPhoneScreen> {
  final _phoneCtrl = TextEditingController();
  bool _isLoading = false;
  bool get _canContinue => _phoneCtrl.text.trim().length >= 10;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    if (!_canContinue) return;
    setState(() => _isLoading = true);
    // In production: call your OTP API here
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isLoading = false);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DriverOtpScreen(phone: _phoneCtrl.text.trim()),
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
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Step indicator
           const StepIndicator(current: 1),
            const SizedBox(height: 28),

            // Heading
            const Text("What's your\nphone number?",
                style: AppTextStyles.display),
            const SizedBox(height: 8),
            Text(
              "We'll send a verification code to confirm it's you.",
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 36),

            // Phone field
           const Text('Phone number', style: AppTextStyles.labelLarge),
            const SizedBox(height: 10),
            PhoneField(
              controller: _phoneCtrl,
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 12),
            const Text(
              'A 6-digit code will be sent via SMS. Standard rates may apply.',
              style: AppTextStyles.caption,
            ),

            const Spacer(),

            PrimaryBtn(
              label: 'Send verification code',
              isLoading: _isLoading,
              enabled: _canContinue,
              onTap: _sendOtp,
            ),
            const SizedBox(height: 14),
            Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                 const Text('Already have an account? ',
                      style: AppTextStyles.bodySmall),
                  GestureDetector(
                    onTap: () => Navigator.pushReplacementNamed(
                        context, AppRoutes.driverAccountSetup),
                    child: Text('Log in',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        )),
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

// ─── OTP Screen ───────────────────────────────────────────────────────────────
/// Inline in same file — same step, same journey.
/// Receives phone from previous screen. On success pushes account setup.
class DriverOtpScreen extends StatefulWidget {
  final String phone;
  const DriverOtpScreen({super.key, required this.phone});

  @override
  State<DriverOtpScreen> createState() => _DriverOtpScreenState();
}

class _DriverOtpScreenState extends State<DriverOtpScreen> {
  final List<TextEditingController> _ctrls =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  int _resendSeconds = 30;
  bool get _codeComplete =>
      _ctrls.every((c) => c.text.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _startResendTimer();
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _nodes[0].requestFocus());
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

  void _onDigit(String value, int index) {
    if (value.isNotEmpty && index < 5) {
      _nodes[index + 1].requestFocus();
    }
    setState(() {});
  }

  void _onBackspace(int index) {
    if (_ctrls[index].text.isEmpty && index > 0) {
      _ctrls[index - 1].clear();
      _nodes[index - 1].requestFocus();
      setState(() {});
    }
  }

  Future<void> _verify() async {
    if (!_codeComplete) return;
    setState(() => _isVerifying = true);
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isVerifying = false);
    Navigator.pushNamed(
      context,
      AppRoutes.driverAccountSetup,
      arguments: widget.phone,
    );
  }

  @override
  void dispose() {
    for (final c in _ctrls) {c.dispose();}
    for (final n in _nodes) {n.dispose();}
    super.dispose();
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
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             const StepIndicator(current: 1),
            const SizedBox(height: 28),

            const Text('Enter the code\nwe sent you',
                style: AppTextStyles.display),
            const SizedBox(height: 8),
            RichText(
              text: TextSpan(
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
                children: [
                  const TextSpan(text: 'Code sent to '),
                  TextSpan(
                    text: widget.phone,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 36),

            // 6-digit input grid
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(6, (i) {
                return SizedBox(
                  width: 46,
                  height: 54,
                  child: TextFormField(
                    controller: _ctrls[i],
                    focusNode: _nodes[i],
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly
                    ],
                    onChanged: (v) => _onDigit(v, i),
                    onEditingComplete: () => _onBackspace(i),
                    style: AppTextStyles.heading2,
                    decoration: InputDecoration(
                      counterText: '',
                      filled: true,
                      fillColor: _ctrls[i].text.isNotEmpty
                          ? AppColors.primary.withValues(alpha: 0.06)
                          : AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide:
                            const BorderSide(color: AppColors.border),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: _ctrls[i].text.isNotEmpty
                              ? AppColors.primary
                              : AppColors.border,
                          width:
                              _ctrls[i].text.isNotEmpty ? 1.5 : 0.5,
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

            const SizedBox(height: 20),

            // Resend row
            Center(
              child: _resendSeconds > 0
                  ? Text(
                      'Resend code in ${_resendSeconds}s',
                      style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textSecondary),
                    )
                  : GestureDetector(
                      onTap: () =>
                          setState(() => _resendSeconds = 30),
                      child: Text(
                        'Resend code',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
            ),

            const Spacer(),

            PrimaryBtn(
              label: 'Verify code',
              isLoading: _isVerifying,
              enabled: _codeComplete,
              onTap: _verify,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Shared auth widgets (used across all 3 signup screens) ──────────────────

/// 3-step progress indicator — shows which step the driver is on.
class StepIndicator extends StatelessWidget {
  final int current; // 1-based

const StepIndicator({super.key, required this.current});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(3, (i) {
        final step = i + 1;
        final isDone    = step < current;
        final isActive  = step == current;
        return Expanded(
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 250),
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: isDone
                      ? AppColors.success
                      : isActive
                          ? AppColors.primary
                          : AppColors.surfaceAlt,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDone
                        ? AppColors.success
                        : isActive
                            ? AppColors.primary
                            : AppColors.border,
                  ),
                ),
                child: Center(
                  child: isDone
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.white, size: 14)
                      : Text(
                          '$step',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isActive
                                ? AppColors.white
                                : AppColors.textTertiary,
                          ),
                        ),
                ),
              ),
              if (i < 2)
                Expanded(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    height: 2,
                    color: isDone ? AppColors.success : AppColors.border,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}

/// Primary action button — shared across all driver auth screens.
class PrimaryBtn extends StatelessWidget {
  final String label;
  final bool isLoading;
  final bool enabled;
  final VoidCallback onTap;

  const PrimaryBtn({
    super.key,
    required this.label,
    required this.isLoading,
    required this.enabled,
    required this.onTap,
  }); 

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled && !isLoading ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: enabled && !isLoading
              ? AppColors.primary
              : AppColors.textTertiary,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: AppColors.white,
                    strokeWidth: 2,
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
        ),
      ),
    );
  }
}


class PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const PhoneField({
    super.key,
    required this.controller,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      onChanged: onChanged,
      decoration: const InputDecoration(
        hintText: 'Enter phone number',
        border: OutlineInputBorder(),
      ),
    );
  }
}