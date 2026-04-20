// features/driver/presentation/screens/driver_documents_screen.dart

import 'package:flutter/material.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../shared/widgets/common/shared_widgets.dart';
import '../../../features/driver/models/driver_type.dart';
import '../../../../app/app_routes.dart';

class DriverDocumentsScreen extends StatefulWidget {
  final DriverType driverType;

  const DriverDocumentsScreen({super.key, required this.driverType});

  @override
  State<DriverDocumentsScreen> createState() => _DriverDocumentsScreenState();
}

class _DriverDocumentsScreenState extends State<DriverDocumentsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      appBar: AppBar(
        title: const Text('Driver Documents'),
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Info banner
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.25),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline_rounded,
                      size: 20, color: AppColors.info),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Please upload the required documents for ${widget.driverType.displayName} verification.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Required Documents',
              style: AppTextStyles.heading3,
            ),

            const SizedBox(height: 16),

            // Document tiles (same as before)
            _buildDocumentTile(
              context: context,
              title: "Driver's License",
              subtitle: 'Upload your valid driver\'s license',
              icon: Icons.credit_card,
              isRequired: true,
            ),

            const SizedBox(height: 12),

            _buildDocumentTile(
              context: context,
              title: 'Vehicle Registration',
              subtitle: 'Upload vehicle registration document',
              icon: Icons.description,
              isRequired: true,
            ),

            const SizedBox(height: 12),

            _buildDocumentTile(
              context: context,
              title: 'Insurance Certificate',
              subtitle: 'Upload valid insurance certificate',
              icon: Icons.security,
              isRequired: true,
            ),

            const SizedBox(height: 12),

            _buildDocumentTile(
              context: context,
              title: 'Profile Photo',
              subtitle: 'Upload a clear profile photo',
              icon: Icons.person,
              isRequired: true,
            ),

            const SizedBox(height: 32),

            // Submit button - Navigates directly to Driver Home
            PrimaryButton(
              label: 'Submit & Continue',
              onTap: () {
                _submitDocumentsAndContinue(context);
              },
            ),

            const SizedBox(height: 16),

            // Note about verification
            Center(
              child: Text(
                'Your documents will be verified within 24-48 hours\nYou can still use the app while verification is pending',
                textAlign: TextAlign.center,
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),

            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  void _submitDocumentsAndContinue(BuildContext context) {
    // Show loading indicator
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(),
      ),
    );

    // Simulate document upload (replace with actual upload logic)
    Future.delayed(const Duration(seconds: 2), () {
      if (!mounted) return;

      // Close loading dialog
      if (mounted) Navigator.pop(context);

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Documents submitted successfully!'),
            backgroundColor: AppColors.successColor,
            duration: Duration(seconds: 2),
          ),
        );

        // Navigate directly to Driver Home
        Navigator.pushNamedAndRemoveUntil(
          context,
          AppRoutes.driverPending,
          (route) => false,
        );
      }
    });
  }

  Widget _buildDocumentTile({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required bool isRequired,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: AppColors.primary, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyMedium.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (isRequired) ...[
                      const SizedBox(width: 4),
                     const  Text(
                        '*',
                        style: TextStyle(
                          color: AppColors.error,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          OutlinedButton(
            onPressed: () {
              _showUploadDialog(context);
            },
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: AppColors.primary),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('Upload'),
          ),
        ],
      ),
    );
  }

  void _showUploadDialog(BuildContext context) {
    // This would open file picker
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('File upload will be implemented'),
        duration: Duration(seconds: 1),
      ),
    );
  }
}
