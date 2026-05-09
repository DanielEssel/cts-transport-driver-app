// lib/features/auth/presentation/role_selection_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../app/app_routes.dart';
import '../../../shared/widgets/buttons/primary_button.dart';
import '../../../core/services/driver_service.dart';

class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole;
  bool _isLoading = false;
  String? _errorMessage;

  static const _roles = [
    _RoleOption(
      id: 'driver_hailing',
      title: 'Carry Passengers',
      subtitle: 'Okada / Motorbike Hailing',
      description:
          'Accept ride requests near you. Earn per trip with instant withdrawals to MoMo.',
      icon: Icons.person_pin_circle_rounded,
      accentColor: AppColors.primaryColor,
      features: ['Ride requests', 'Okada only', 'Instant Payouts'],
    ),
    _RoleOption(
      id: 'driver_delivery',
      title: 'Deliver Goods',
      subtitle: 'Logistics & Parcels',
      description:
          'Matched by vehicle size: Motorbike, Tricycle (Aboboyaa), or Mini Truck.',
      icon: Icons.inventory_2_rounded,
      accentColor: Color(0xFF2D31FA),
      features: ['Multi-vehicle support', 'Flexible loads', 'Route optimization'],
    ),
  ];

  Future<void> _onContinue() async {
    if (_selectedRole == null || _isLoading) return;
    HapticFeedback.mediumImpact();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // 1. Save role to Firestore
      await DriverService.updateDriver({'role': _selectedRole});

      // 2. Get the verified phone from Firebase Auth — never hardcode
      final phone =
          FirebaseAuth.instance.currentUser?.phoneNumber ?? '';

      if (!mounted) return;

      // 3. Navigate — pass phone so driverPhone screen can pre-fill
      Navigator.of(context).pushNamed(
        AppRoutes.driverPhone,
        arguments: {'phone': phone, 'role': _selectedRole},
      );
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to save your selection. Please try again.';
      });
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
          icon: const Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: AppColors.textPrimaryColor,
          ),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Choose your path",
                    style: AppTextStyles.headingMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    "Select how you want to earn with CTS Africa. This configures your dashboard.",
                    style: AppTextStyles.bodyMedium
                        .copyWith(color: AppColors.textSecondaryColor),
                  ),
                  const SizedBox(height: 32),
                  ..._roles.map((role) => _buildRoleCard(role)),

                  // ── Error ────────────────────────────────────────────────
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
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
                ],
              ),
            ),
          ),

          // ── Sticky footer ────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: AppColors.backgroundColor,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: PrimaryButton(
              label: _selectedRole == null
                  ? "Select a Role"
                  : "Confirm Selection",
              // null disables the button properly
              onPressed: _selectedRole != null && !_isLoading
                  ? _onContinue
                  : null,
              isLoading: _isLoading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(_RoleOption role) {
    final isSelected = _selectedRole == role.id;

    return GestureDetector(
      onTap: _isLoading
          ? null
          : () {
              HapticFeedback.lightImpact();
              setState(() => _selectedRole = role.id);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isSelected
              ? role.accentColor.withOpacity(0.05)
              : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? role.accentColor
                : AppColors.textSecondaryColor.withOpacity(0.1),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? role.accentColor
                        : AppColors.textSecondaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    role.icon,
                    color: isSelected
                        ? Colors.white
                        : AppColors.textSecondaryColor,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        role.title,
                        style: AppTextStyles.bodyMedium
                            .copyWith(fontWeight: FontWeight.bold),
                      ),
                      Text(role.subtitle,
                          style: AppTextStyles.bodySmall),
                    ],
                  ),
                ),
                Radio<String>(
                  value: role.id,
                  groupValue: _selectedRole,
                  onChanged: _isLoading
                      ? null
                      : (val) => setState(() => _selectedRole = val),
                  activeColor: role.accentColor,
                ),
              ],
            ),
            if (isSelected) ...[
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 8),
              Text(role.description, style: AppTextStyles.bodySmall),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: role.features
                    .map(
                      (f) => Chip(
                        label: Text(f,
                            style: const TextStyle(fontSize: 10)),
                        backgroundColor:
                            role.accentColor.withOpacity(0.1),
                        side: BorderSide.none,
                        visualDensity: VisualDensity.compact,
                      ),
                    )
                    .toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Role option model ─────────────────────────────────────────────────────────
class _RoleOption {
  final String id, title, subtitle, description;
  final IconData icon;
  final Color accentColor;
  final List<String> features;

  const _RoleOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.accentColor,
    required this.features,
  });
}