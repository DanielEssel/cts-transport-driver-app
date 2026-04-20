import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../app/app_routes.dart';
import 'driver_phone_screen.dart';
import '../../../driver_auth/presentation/widgets/driver_auth_widgets.dart';

/// Screen 2 of 3 — Name + Password.
/// No email (optional — collected later in profile).
/// No confirm password — show/hide toggle instead.
/// On success pushes to vehicle setup (screen 3).
class DriverAccountSetupScreen extends StatefulWidget {
  final String phone;
  const DriverAccountSetupScreen({super.key, required this.phone});

  @override
  State<DriverAccountSetupScreen> createState() =>
      _DriverAccountSetupScreenState();
}

class _DriverAccountSetupScreenState
    extends State<DriverAccountSetupScreen> {
  final _formKey       = GlobalKey<FormState>();
  final _nameCtrl      = TextEditingController();
  final _passwordCtrl  = TextEditingController();
  bool _obscurePass    = true;
  bool _isLoading      = false;
  bool _agreedToTerms  = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  bool get _canContinue =>
      _nameCtrl.text.trim().isNotEmpty &&
      _passwordCtrl.text.length >= 6 &&
      _agreedToTerms;

  Future<void> _continue() async {
    if (!_formKey.currentState!.validate() || !_agreedToTerms) {
      if (!_agreedToTerms) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Please agree to the terms to continue'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
      return;
    }
    setState(() => _isLoading = true);
    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted) return;
    setState(() => _isLoading = false);
    // Proceed to vehicle setup (screen 3)
    Navigator.pushNamed(context, AppRoutes.driverVehicleSetup);
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
      body: Form(
        key: _formKey,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
             const StepIndicator(current: 2),
              const SizedBox(height: 28),

              const Text('Set up your\naccount', style: AppTextStyles.display),
              const SizedBox(height: 8),
              Text(
                'How should riders know you?',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: 36),

              // ── Full name ──────────────────────────────────────────────
             const _FieldLabel('Full name'),
              const SizedBox(height: 10),
              _InputField(
                controller: _nameCtrl,
                hint: 'e.g. Kwame Asante',
                icon: Icons.person_rounded,
                onChanged: (_) => setState(() {}),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Name is required' : null,
              ),
              const SizedBox(height: 20),

              // ── Password ───────────────────────────────────────────────
             const _FieldLabel('Password'),
              const SizedBox(height: 10),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscurePass,
                onChanged: (_) => setState(() {}),
                validator: (v) => v == null || v.length < 6
                    ? 'Minimum 6 characters'
                    : null,
                style: AppTextStyles.bodyMedium,
                decoration: InputDecoration(
                  hintText: 'Minimum 6 characters',
                  hintStyle: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textTertiary),
                  prefixIcon: const Icon(Icons.lock_rounded,
                      size: 18, color: AppColors.textSecondary),
                  suffixIcon: GestureDetector(
                    onTap: () =>
                        setState(() => _obscurePass = !_obscurePass),
                    child: Icon(
                      _obscurePass
                          ? Icons.visibility_rounded
                          : Icons.visibility_off_rounded,
                      size: 18,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(
                        color: AppColors.primary, width: 1.5),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.error),
                  ),
                ),
              ),

              // Password strength indicator
              if (_passwordCtrl.text.isNotEmpty) ...[
                const SizedBox(height: 8),
                _PasswordStrength(password: _passwordCtrl.text),
              ],

              const SizedBox(height: 24),

              // ── Terms ──────────────────────────────────────────────────
              GestureDetector(
                onTap: () =>
                    setState(() => _agreedToTerms = !_agreedToTerms),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        color: _agreedToTerms
                            ? AppColors.primary
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: _agreedToTerms
                              ? AppColors.primary
                              : AppColors.border,
                          width: 1.5,
                        ),
                      ),
                      child: _agreedToTerms
                          ? const Icon(Icons.check_rounded,
                              color: AppColors.white, size: 14)
                          : null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary),
                          children: const [
                             TextSpan(text: 'I agree to the '),
                            TextSpan(
                              text: 'Terms of Service',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                             TextSpan(text: ' and '),
                            TextSpan(
                              text: 'Privacy Policy',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const Spacer(),

              PrimaryBtn(
                label: 'Continue',
                isLoading: _isLoading,
                enabled: _canContinue,
                onTap: _continue,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Password strength widget ─────────────────────────────────────────────────
class _PasswordStrength extends StatelessWidget {
  final String password;
  const _PasswordStrength({required this.password});

  int get _score {
    int s = 0;
    if (password.length >= 6) s++;
    if (password.length >= 10) s++;
    if (password.contains(RegExp(r'[A-Z]'))) s++;
    if (password.contains(RegExp(r'[0-9]'))) s++;
    if (password.contains(RegExp(r'[!@#\$%^&*]'))) s++;
    return s;
  }

  @override
  Widget build(BuildContext context) {
    final labels = ['Too short', 'Weak', 'Fair', 'Good', 'Strong'];
    final colors = [
      AppColors.error,
      AppColors.error,
      AppColors.warning,
      AppColors.warning,
      AppColors.success,
    ];
    final score = _score.clamp(0, 4);

    return Row(
      children: [
        ...List.generate(4, (i) {
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
              height: 3,
              decoration: BoxDecoration(
                color: i < score
                    ? colors[score]
                    : AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
        const SizedBox(width: 8),
        Text(
          labels[score],
          style: AppTextStyles.caption.copyWith(
            color: colors[score],
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ─── Shared local widgets ─────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) =>
      Text(text, style: AppTextStyles.labelLarge);
}

class _InputField extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final IconData icon;
  final ValueChanged<String>? onChanged;
  final String? Function(String?)? validator;

  const _InputField({
    required this.controller,
    required this.hint,
    required this.icon,
    this.onChanged,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      onChanged: onChanged,
      validator: validator,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTextStyles.bodySmall
            .copyWith(color: AppColors.textTertiary),
        prefixIcon:
            Icon(icon, size: 18, color: AppColors.textSecondary),
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
    );
  }
}