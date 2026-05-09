import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/services.dart'; // For Haptic Feedback
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../app/app_routes.dart';
import '../../../shared/widgets/buttons/primary_button.dart';
import '../../../shared/widgets/textfields/custom_textfield.dart';
import '../../../shared/utils/phone_formatter.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _phoneController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;
  String? _errorMessage;

  // Animation controller for the "Entrance" effect
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation =
        CurvedAnimation(parent: _animationController, curve: Curves.easeIn);
    _animationController.forward();
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  // Define the missing friendly error method
  String _friendlyError(String code) {
    switch (code) {
      case 'invalid-phone-number':
        return 'Enter a valid Ghana phone number.';
      case 'too-many-requests':
        return 'Too many attempts. Please wait a moment.';
      case 'network-request-failed':
        return 'Check your internet connection and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }

  // Improved normalization logic
  String _normalizePhone(String raw) {
    final cleaned = raw.trim().replaceAll(RegExp(r'\D'), '');
    if (cleaned.startsWith('233')) return '+$cleaned';
    if (cleaned.startsWith('0')) return '+233${cleaned.substring(1)}';
    return '+233$cleaned';
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) {
      HapticFeedback.vibrate();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final phone = _normalizePhone(_phoneController.text);

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        // ... rest of your Firebase logic stays the same ...
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
              'isDriverLogin': true,
            },
          );
        },
        verificationCompleted: (cred) async {/*...*/},
        verificationFailed: (e) {
          setState(() {
            _isLoading = false;
            _errorMessage = _friendlyError(e.code);
          });
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Service unavailable. Try again.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      // Allow the background to sit behind the status bar
      extendBodyBehindAppBar: true,
      body: Stack(
        children: [
          // 1. Background Pattern (Subtle Map or Gradient)
          Positioned(
            top: -100,
            right: -50,
            child: CircleAvatar(
              radius: 150,
              backgroundColor: AppColors.primaryColor.withOpacity(0.05),
            ),
          ),

          SafeArea(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 32),

                      // 2. Branding/Logo Placeholder
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Icon(Icons.directions_car_filled_rounded,
                            color: AppColors.primaryColor, size: 32),
                      ),

                      const SizedBox(height: 24),
                      const Text(
                        "Welcome back",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.5,
                          color: Color(0xFF1A1A1A),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Ready for your next trip?",
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.textSecondaryColor,
                        ),
                      ),

                      const SizedBox(height: 40),

                      // 3. Modernized Phone Input
                      CustomTextField(
                        label: "Phone Number",
                        hint: "024 XXX XXXX",
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                        maxLength: 12,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          GhanaPhoneFormatter(), // ← inside the list, not outside
                        ],
                        prefixIcon: _buildCountryPicker(),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Required';
                          }
                          final digits = value.replaceAll(' ', '');
                          if (digits.length != 10) {
                            return 'Enter a valid 10-digit Ghana number';
                          }
                          return null;
                        },
                      ),

                      if (_errorMessage != null) _buildErrorWidget(),

                      const Spacer(),

                      // 4. Integrated Action Area
                      Column(
                        children: [
                          PrimaryButton(
                            label: "Continue",
                            onPressed: _isLoading ? null : _login,
                            isLoading: _isLoading,
                          ),
                          const SizedBox(height: 20),
                          const Row(
                            children: [
                              Expanded(child: Divider()),
                              Padding(
                                padding:
                                    EdgeInsets.symmetric(horizontal: 16),
                                child:
                                    Text("OR", style: AppTextStyles.bodySmall),
                              ),
                              Expanded(child: Divider()),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const SizedBox(height: 12),
                          OutlinedButton(
                            onPressed: () =>
                                Navigator.pushNamed(context, AppRoutes.signup),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 52),
                              side: const BorderSide(
                                  color: AppColors.primaryColor, width: 1.5),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              "Create new account",
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.primaryColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Refactored helper widgets for cleaner build method
  Widget _buildCountryPicker() {
    return IntrinsicHeight(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(width: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Image.network(
              'https://flagcdn.com/w40/gh.png',
              width: 24,
              errorBuilder: (_, __, ___) => const Text('🇬🇭'),
            ),
          ),
          const SizedBox(width: 8),
          const Text("+233",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const VerticalDivider(indent: 12, endIndent: 12, width: 24),
        ],
      ),
    );
  }

  Widget _buildErrorWidget() {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade100),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
          const SizedBox(width: 12),
          Expanded(
              child: Text(_errorMessage!,
                  style: TextStyle(color: Colors.red.shade700, fontSize: 13))),
        ],
      ),
    );
  }
}
