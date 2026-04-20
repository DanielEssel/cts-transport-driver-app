import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../app/app_routes.dart';
import 'driver_phone_screen.dart';
import 'driver_forgot_password_screen.dart';


/// Driver login screen.
/// Single screen — phone + password.
/// After success: routes based on stored driver status:
///   approved driver  → AppRoutes.driverShell
///   pending driver   → AppRoutes.driverPending
/// (In production replace the mock sheet with a real profile fetch.)
class DriverLoginScreen extends StatefulWidget {
  const DriverLoginScreen({super.key});

  @override
  State<DriverLoginScreen> createState() => _DriverLoginScreenState();
}

class _DriverLoginScreenState extends State<DriverLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _obscure = true;
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);
    // In production: call auth API, get back role + approval status
    await Future.delayed(const Duration(seconds: 1));
    if (!mounted) return;
    setState(() => _isLoading = false);
    _showRoleSheet(); // mock — replace with API-driven routing
  }

  /// Mock role-check sheet.
  /// In production this is replaced by:
  ///   final profile = await AuthService.login(phone, password);
  ///   if (profile.isDriver && profile.isApproved)
  ///     Navigator.pushNamedAndRemoveUntil(context, AppRoutes.driverShell, ...)
  ///   else if (profile.isDriver && !profile.isApproved)
  ///     Navigator.pushReplacement(context, DriverPendingScreen(...))
  void _showRoleSheet() {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      isDismissible: false,
      enableDrag: false,
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 20),
            const Text('Continue as', style: AppTextStyles.heading3),
            const SizedBox(height: 4),
            Text('Select your account type for this session',
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: 20),
            // Approved driver
            _SessionTile(
              icon: Icons.check_circle_rounded,
              iconColor: AppColors.success,
              title: 'Driver (approved)',
              subtitle: 'Go to your driver dashboard',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(
                    context, AppRoutes.driverShell, (r) => false);
              },
            ),
            const SizedBox(height: 10),
            // Pending driver
            _SessionTile(
              icon: Icons.hourglass_top_rounded,
              iconColor: AppColors.warning,
              title: 'Driver (pending approval)',
              subtitle: 'Check your application status',
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamedAndRemoveUntil(
                    context, AppRoutes.driverPending, (r) => false);
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo mark
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(Icons.directions_car_rounded,
                      color: AppColors.white, size: 24),
                ),
                const SizedBox(height: 24),

                const Text('Welcome back,\nDriver 👋',
                    style: AppTextStyles.display),
                const SizedBox(height: 8),
                Text(
                  'Sign in to start accepting requests.',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 36),

                // Phone
                const Text('Phone number', style: AppTextStyles.labelLarge),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _phoneCtrl,
                  keyboardType: TextInputType.phone,
                  style: AppTextStyles.bodyMedium,
                  validator: (v) => v == null || v.trim().length < 10
                      ? 'Enter a valid phone number'
                      : null,
                  decoration: _inputDecoration(
                    hint: '+233 XX XXX XXXX',
                    icon: Icons.phone_rounded,
                  ),
                ),
                const SizedBox(height: 18),

                // Password
                const Text('Password', style: AppTextStyles.labelLarge),
                const SizedBox(height: 10),
                TextFormField(
                  controller: _passCtrl,
                  obscureText: _obscure,
                  style: AppTextStyles.bodyMedium,
                  validator: (v) =>
                      v == null || v.length < 6 ? 'Minimum 6 characters' : null,
                  decoration: _inputDecoration(
                    hint: 'Enter your password',
                    icon: Icons.lock_rounded,
                    suffix: GestureDetector(
                      onTap: () => setState(() => _obscure = !_obscure),
                      child: Icon(
                        _obscure
                            ? Icons.visibility_rounded
                            : Icons.visibility_off_rounded,
                        size: 18,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                ),

                // Forgot password
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const DriverForgotPasswordScreen()),
                    ),
                    child: Text(
                      'Forgot password?',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                PrimaryBtn(
                  label: 'Sign in',
                  isLoading: _isLoading,
                  enabled: true,
                  onTap: _login,
                ),
                const SizedBox(height: 16),
                Center(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                     const Text("Don't have an account? ",
                          style: AppTextStyles.bodySmall),
                      GestureDetector(
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const DriverPhoneScreen()),
                        ),
                        child: Text(
                          'Sign up',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w700,
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
    );
  }

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
    Widget? suffix,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle:
          AppTextStyles.bodySmall.copyWith(color: AppColors.textTertiary),
      prefixIcon: Icon(icon, size: 18, color: AppColors.textSecondary),
      suffixIcon: suffix,
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
        borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.error),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title, subtitle;
  final VoidCallback onTap;

  const _SessionTile({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: iconColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.labelLarge),
                  Text(subtitle, style: AppTextStyles.caption),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded,
                color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}
