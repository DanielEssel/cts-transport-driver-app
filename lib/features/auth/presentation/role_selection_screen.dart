// features/auth/presentation/role_selection_screen.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_strings.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../core/routes/app_routes.dart';
import '../../../widgets/buttons/primary_button.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({Key? key}) : super(key: key);

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;

  void _continueWithRole() {
    if (_selectedRole != null) {
      if (_selectedRole == 'rider') {
        Navigator.of(context).pushReplacementNamed(AppRoutes.riderHome);
      } else {
        Navigator.of(context).pushReplacementNamed(AppRoutes.driverHome);
      }
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
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimaryColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                AppStrings.roleSelectionTitle,
                style: AppTextStyles.headingMedium,
              ),
              const SizedBox(height: 8),
              Text(
                AppStrings.roleSelectionSubtitle,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textSecondaryColor,
                ),
              ),
              const SizedBox(height: 40),
              _RoleCard(
                title: AppStrings.riderRole,
                description: AppStrings.riderRoleDesc,
                icon: Icons.person,
                isSelected: _selectedRole == 'rider',
                onTap: () => setState(() => _selectedRole = 'rider'),
              ),
              const SizedBox(height: 20),
              _RoleCard(
                title: AppStrings.driverRole,
                description: AppStrings.driverRoleDesc,
                icon: Icons.directions_car,
                isSelected: _selectedRole == 'driver',
                onTap: () => setState(() => _selectedRole = 'driver'),
              ),
              const SizedBox(height: 48),
              PrimaryButton(
                label: AppStrings.continueButton,
                onPressed: _continueWithRole,
                isDisabled: _selectedRole == null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoleCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _RoleCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primaryColor : AppColors.borderColor,
            width: isSelected ? 2 : 1,
          ),
          color: isSelected
              ? AppColors.primaryColor.withOpacity(0.05)
              : AppColors.backgroundColor,
        ),
        child: Row(
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: AppColors.primaryColor.withOpacity(0.1),
              ),
              child: Icon(icon, color: AppColors.primaryColor, size: 32),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(description, style: AppTextStyles.bodySmall),
                ],
              ),
            ),
            Icon(
              isSelected ? Icons.check_circle : Icons.circle_outlined,
              color: isSelected
                  ? AppColors.primaryColor
                  : AppColors.borderColor,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }
}
