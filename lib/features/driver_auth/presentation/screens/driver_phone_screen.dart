import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../app/app_routes.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/widgets/common/shared_widgets.dart';

import '../../../../core/services/onboarding_state_machine.dart';
import '../../../../core/models/signup_step.dart';
import '../../../../core/services/driver_flow_resolver.dart';

class DriverPhoneScreen extends StatefulWidget {
  final String verifiedPhone;

  const DriverPhoneScreen({
    super.key,
    required this.verifiedPhone,
  });

  @override
  State<DriverPhoneScreen> createState() => _DriverPhoneScreenState();
}

class _DriverPhoneScreenState extends State<DriverPhoneScreen> {
  bool _isLoading = false;
  bool _isSubmitting = false;
  String? _errorMessage;

  Future<void> _onContinue() async {
  if (_isSubmitting) return;

  setState(() {
    _isLoading = true;
    _isSubmitting = true;
    _errorMessage = null;
  });

  try {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      Navigator.pushReplacementNamed(context, '/login');
      return;
    }

    // ✅ 1. Update Firestore to move PAST the phone verification check
    // Ensure this matches the logic your Resolver uses to determine 'accountSetupComplete'
    await OnboardingStateMachine.setStep(
      user.uid,
      SignupStep.roleSelected, // Change this to a step that EXCEEDS 'phoneVerified'
    );

    // ✅ 2. Force a clean resolution
    final destination = await AppFlowResolver.resolveDestination(user.uid);

    if (!mounted) return;

    // ✅ 3. If the destination is STILL this screen, we force-override it 
    // to prevent the loop while debugging.
    if (destination.route == AppRoutes.driverPhone) {
       Navigator.pushNamed(context, AppRoutes.driverAccountSetup); // Use your actual setup route name
    } else {
      Navigator.pushReplacementNamed(
        context,
        destination.route,
        arguments: destination.arguments,
      );
    }
  } catch (e) {
    setState(() => _errorMessage = 'Unable to move to setup.');
  } finally {
    if (mounted) setState(() { _isLoading = false; _isSubmitting = false; });
  }
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
          onTap: _isLoading ? null : () => Navigator.pop(context),
          child: Container(
            margin: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.surfaceAlt,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: const Icon(
              Icons.arrow_back_ios_new_rounded,
              size: 16,
              color: AppColors.textPrimary,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const OnboardingStepIndicator(current: 1, total: 3),

            const SizedBox(height: 28),
            const Text("Confirm your\naccount",
                style: AppTextStyles.display),

            const SizedBox(height: 8),
            Text(
              "Your phone number is verified. Let's finish setting up your driver profile.",
              style: AppTextStyles.bodySmall
                  .copyWith(color: AppColors.textSecondary),
            ),

            const SizedBox(height: 36),

            const Text('Verified phone number',
                style: AppTextStyles.labelLarge),

            const SizedBox(height: 10),

            Container(
              width: double.infinity,
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
              decoration: BoxDecoration(
                color: AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(14),
                border:
                    Border.all(color: AppColors.success.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.check_circle_rounded,
                      color: AppColors.success, size: 20),
                  const SizedBox(width: 12),
                  Text(
                    widget.verifiedPhone,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
            ),

            if (_errorMessage != null) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.red.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(10),
                  border:
                      Border.all(color: Colors.red.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline_rounded,
                        color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _errorMessage!,
                        style: AppTextStyles.bodySmall
                            .copyWith(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Spacer(),

            PrimaryButton(
              label: 'Setup account details',
              isLoading: _isLoading,
              enabled: !_isLoading,
              onTap: _onContinue,
            ),

            const SizedBox(height: 14),

            const Center(
              child: Text(
                'This number will be used for your payouts.',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption,
              ),
            ),
          ],
        ),
      ),
    );
  }
}