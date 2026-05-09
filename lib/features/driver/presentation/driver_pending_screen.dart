import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../app/app_routes.dart';

class DriverPendingScreen extends StatelessWidget {
  const DriverPendingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const Spacer(flex: 2),
                      
                      // Brand Identity Placeholder (Replaces failing logo asset)
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: 140,
                            height: 140,
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.05),
                              shape: BoxShape.circle,
                            ),
                          ),
                          const Icon(
                            Icons.history_toggle_off_rounded,
                            size: 80,
                            color: AppColors.primaryColor,
                          ),
                        ],
                      ),
                      
                      const SizedBox(height: 40),

                      const Text(
                        "Verification Pending",
                        style: AppTextStyles.display,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: Text(
                          "We've received your documents. Our team is currently reviewing them to get you on the road.",
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodySmall.copyWith(color: AppColors.textSecondary),
                        ),
                      ),

                      const SizedBox(height: 48),

                      // Status Timeline
                      _buildStatusTimeline(),

                      const Spacer(flex: 3),

                      // Support Card
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceAlt,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.support_agent_rounded, color: AppColors.primary, size: 20),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    "Need help with your application?",
                                    style: AppTextStyles.labelLarge.copyWith(fontSize: 14),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              "Contact our support line if you have questions regarding your document status.",
                              style: AppTextStyles.caption,
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),

                      // CTA Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: () {
                            Navigator.pushNamedAndRemoveUntil(
                              context,
                              AppRoutes.login,
                              (route) => false,
                            );
                          },
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: const BorderSide(color: AppColors.border),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text(
                            "Return to Login",
                            style: AppTextStyles.labelLarge.copyWith(color: AppColors.textPrimary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildStatusTimeline() {
    return Column(
      children: [
        _buildTimelineStep(
          title: "Documents Submitted",
          time: "Just now",
          isCompleted: true,
          isLast: false,
        ),
        _buildTimelineStep(
          title: "Under Review",
          time: "Usually takes 24h",
          isCompleted: false,
          isCurrent: true,
          isLast: false,
        ),
        _buildTimelineStep(
          title: "Account Activated",
          time: "Final Step",
          isCompleted: false,
          isLast: true,
        ),
      ],
    );
  }

  Widget _buildTimelineStep({
    required String title,
    required String time,
    required bool isCompleted,
    bool isCurrent = false,
    required bool isLast,
  }) {
    return SizedBox(
      height: 60,
      child: Row(
        children: [
          Column(
            children: [
              Icon(
                isCompleted ? Icons.check_circle : isCurrent ? Icons.circle : Icons.circle_outlined,
                color: isCompleted ? AppColors.success : isCurrent ? AppColors.primary : AppColors.border,
                size: 20,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted ? AppColors.success : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTextStyles.labelLarge.copyWith(
                  color: isCurrent || isCompleted ? AppColors.textPrimary : AppColors.textTertiary,
                ),
              ),
              Text(time, style: AppTextStyles.caption),
            ],
          ),
        ],
      ),
    );
  }
}