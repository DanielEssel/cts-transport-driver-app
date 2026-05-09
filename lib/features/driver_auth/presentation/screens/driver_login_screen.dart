import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../app/app_routes.dart';
import '../../../../shared/widgets/buttons/primary_button.dart';
import '../../../../shared/widgets/textfields/custom_textfield.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = false;
  String? _error;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  // ── Normalize Ghana number ─────────────────────────────────────────
  String _normalizePhone(String raw) {
    final cleaned = raw.trim().replaceAll(' ', '');
    if (cleaned.startsWith('+233')) return cleaned;
    if (cleaned.startsWith('0')) return '+233${cleaned.substring(1)}';
    if (cleaned.startsWith('233')) return '+$cleaned';
    return '+233$cleaned';
  }

  // ── Send OTP (Login = re-auth via OTP) ─────────────────────────────
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    final phone = _normalizePhone(_phoneController.text);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,

        codeSent: (verificationId, resendToken) {
          if (!mounted) return;
          setState(() => _isLoading = false);

          Navigator.pushNamed(
            context,
            AppRoutes.otpVerification,
            arguments: {
              'phone': phone,
              'verificationId': verificationId,
              'resendToken': resendToken,
              'isLogin': true, // 👈 important flag
            },
          );
        },

        verificationFailed: (e) {
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _error = _friendlyError(e.code);
          });
        },

        verificationCompleted: (cred) async {
          await FirebaseAuth.instance.signInWithCredential(cred);
          if (!mounted) return;

          Navigator.pushNamedAndRemoveUntil(
            context,
            AppRoutes.splash,
            (route) => false,
          );
        },

        codeAutoRetrievalTimeout: (_) {},
        timeout: const Duration(seconds: 60),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _error = 'Login failed. Try again.';
      });
    }
  }

  String _friendlyError(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Invalid phone number';
      case 'too-many-requests':
        return 'Too many attempts. Try later.';
      default:
        return 'Something went wrong';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded,
              color: AppColors.textPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 40),

                const Text(
                  "Welcome back",
                  style: AppTextStyles.headingMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  "Enter your phone number to continue",
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondaryColor,
                  ),
                ),

                const SizedBox(height: 40),

                CustomTextField(
                  label: "Phone Number",
                  hint: "024XXXXXXX",
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                ),

                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],

                const SizedBox(height: 40),

                PrimaryButton(
                  label: "Login",
                  onPressed: _isLoading ? null : _login,
                  isLoading: _isLoading,
                ),

                const SizedBox(height: 24),

                Center(
                  child: TextButton(
                    onPressed: () =>
                        Navigator.pushNamed(context, AppRoutes.signup),
                    child: const Text("Create new account"),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}