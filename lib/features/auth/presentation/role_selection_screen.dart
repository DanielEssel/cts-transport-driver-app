import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../app/app_routes.dart';
import '../../../shared/widgets/common/shared_widgets.dart';
import '../../driver/models/driver_type.dart' as driver;

/// Role selection — driver only.
/// Two choices: carry passengers (hailing) or deliver goods.
/// Riders have their own separate onboarding flow.
class RoleSelectionScreen extends StatefulWidget {
  const RoleSelectionScreen({super.key});

  @override
  State<RoleSelectionScreen> createState() => _RoleSelectionScreenState();
}

class _RoleSelectionScreenState extends State<RoleSelectionScreen> {
  String? _selectedRole; // 'driver_hailing' | 'driver_delivery'

  static const _roles = [
    _RoleOption(
      id: 'driver_hailing',
      title: 'Carry Passengers',
      subtitle: 'Pick up and drop off passengers on your motorbike',
      description:
          'Accept ride requests near you. Earn per trip and withdraw to MoMo anytime. Only Okada (motorbike) drivers can carry passengers.',
      icon: Icons.hail_rounded,
      accentColor: Color(0xFFFF6B35),
      features: [
        'Ride requests only',
        'Okada motorbike',
        'Earn per trip',
        'Daily withdrawals',
      ],
    ),
    _RoleOption(
      id: 'driver_delivery',
      title: 'Deliver Goods',
      subtitle: 'Carry parcels and goods with your vehicle',
      description:
          'Accept delivery jobs matched to your vehicle size — motorbike, tricycle or mini truck. The bigger your vehicle, the bigger the loads.',
      icon: Icons.local_shipping_rounded,
      accentColor: Color(0xFF1A1A2E),
      features: [
        'Matched by vehicle size',
        'Okada · Aboboya · Truck',
        'Earn per delivery',
        'Daily withdrawals',
      ],
    ),
  ];

  void _onContinue() {
    if (_selectedRole == null) return;
    switch (_selectedRole) {
      case 'driver_hailing':
        // DriverType already known — go straight to signup (phone screen)
        Navigator.pushNamed(
          context,
          AppRoutes.driverPhone,
          arguments: driver.DriverType.okadaHailing,
        );
        break;
      case 'driver_delivery':
        // Need to pick vehicle first — vehicle setup will set the final DriverType
        Navigator.pushNamed(context, AppRoutes.driverPhone);
        break;
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
      body: Column(
        children: [
          // ── Scrollable content ────────────────────────────────────────
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'What will you\ndo with RideGo?',
                    style: AppTextStyles.display,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Choose how you want to earn. This determines what requests you receive.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),

                  ..._roles.map(_buildRoleCard),

                  const SizedBox(height: 8),

                  // Note at bottom
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: const Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline_rounded,
                            size: 15, color: AppColors.textTertiary),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'You can only change your role by contacting support. Choose carefully.',
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              color: AppColors.textSecondary,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ),

          // ── Sticky footer ─────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
            decoration: const BoxDecoration(
              color: AppColors.surface,
              border: Border(
                  top: BorderSide(color: AppColors.border, width: 0.5)),
            ),
            child: PrimaryButton(
              label: _selectedRole == null
                  ? 'Select an option to continue'
                  : _selectedRole == 'driver_hailing'
                      ? 'Continue — Carry Passengers'
                      : 'Continue — Deliver Goods',
              onTap: _selectedRole != null ? _onContinue : null,
              color: _selectedRole != null ? null : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoleCard(_RoleOption role) {
    final isSelected = _selectedRole == role.id;
    return GestureDetector(
      onTap: () => setState(() => _selectedRole = role.id),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected
              ? role.accentColor.withValues(alpha: 0.05)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? role.accentColor : AppColors.border,
            width: isSelected ? 2 : 0.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header row ──────────────────────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: role.accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(role.icon,
                      color: role.accentColor, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(role.title, style: AppTextStyles.heading3),
                      const SizedBox(height: 4),
                      Text(role.subtitle,
                          style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.textSecondary)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? role.accentColor
                        : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected
                          ? role.accentColor
                          : AppColors.border,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check_rounded,
                          color: AppColors.white, size: 14)
                      : null,
                ),
              ],
            ),

            // ── Expanded detail (only when selected) ───────────────────
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 200),
              crossFadeState: isSelected
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox(width: double.infinity),
              secondChild: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 14),
                  Container(height: 0.5, color: AppColors.border),
                  const SizedBox(height: 12),
                  Text(
                    role.description,
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: role.features
                        .map((f) => Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: role.accentColor
                                    .withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(Icons.check_rounded,
                                      size: 11,
                                      color: role.accentColor),
                                  const SizedBox(width: 4),
                                  Text(
                                    f,
                                    style: AppTextStyles.caption.copyWith(
                                      color: role.accentColor,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ))
                        .toList(),
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

// ─── Data class ───────────────────────────────────────────────────────────────

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