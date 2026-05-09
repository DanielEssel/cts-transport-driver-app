// lib/features/driver/presentation/driver_vehicle_setup_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../app/app_routes.dart';
import '../../../shared/widgets/common/shared_widgets.dart';
import '../models/driver_types.dart';
import '../../../core/services/driver_service.dart';

class DriverVehicleSetupScreen extends StatefulWidget {
  const DriverVehicleSetupScreen({super.key});

  @override
  State<DriverVehicleSetupScreen> createState() =>
      _DriverVehicleSetupScreenState();
}

class _DriverVehicleSetupScreenState
    extends State<DriverVehicleSetupScreen> {
  DriverVehicleType? _selected;
  bool _isLoading = false;
  String? _errorMessage;

  static const _options = [
    _VehicleOption(
      type: DriverVehicleType.motorbike,
      title: 'Motorbike',
      subtitle: 'Okada / Motorcycle',
      description: 'Perfect for ride-hailing and small deliveries in traffic.',
      icon: '🏍️',
    ),
    _VehicleOption(
      type: DriverVehicleType.aboboyaa,
      title: 'Tricycle',
      subtitle: 'Aboboyaa / Cargo Tricycle',
      description: 'Great for medium loads and local logistics.',
      icon: '🛺',
    ),
    _VehicleOption(
      type: DriverVehicleType.miniTruck,
      title: 'Mini Truck',
      subtitle: 'Pickup / Mini Van',
      description: 'Ideal for large deliveries and bulk cargo.',
      icon: '🚚',
    ),
  ];

  Future<void> _continue() async {
    if (_selected == null || _isLoading) return;
    HapticFeedback.mediumImpact();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Map enum to string for Firestore
      final vehicleTypeStr = switch (_selected!) {
        DriverVehicleType.motorbike => 'motorcycle',
        DriverVehicleType.aboboyaa => 'tricycle',
        DriverVehicleType.miniTruck => 'miniTruck',
        DriverVehicleType.pragyia => 'pragyia',
        DriverVehicleType.taxi => 'taxi',
        DriverVehicleType.quadricycle => 'quadricycle',
      };

      await DriverService.updateDriver({
  'vehicleType': vehicleTypeStr,
  'vehicleSetupComplete': true,
});

      if (!mounted) return;
      Navigator.pushNamed(context, AppRoutes.driverDocuments);
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Could not save your vehicle. Please try again.';
      });
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
            child: const Icon(Icons.arrow_back_ios_new_rounded,
                size: 16, color: AppColors.textPrimary),
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const OnboardingStepIndicator(current: 3, total: 4),
                  const SizedBox(height: 28),

                  const Text('Your vehicle\ntype',
                      style: AppTextStyles.display),
                  const SizedBox(height: 8),
                  Text(
                    'Select the vehicle you will be using on the platform.',
                    style: AppTextStyles.bodySmall
                        .copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 32),

                  // ── Vehicle cards ────────────────────────────────────
                  ..._options.map((opt) => _buildVehicleCard(opt)),

                  // ── Error ────────────────────────────────────────────
                  if (_errorMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: Colors.red.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: Colors.red.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: Colors.red, size: 16),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(_errorMessage!,
                                style: AppTextStyles.bodySmall
                                    .copyWith(color: Colors.red)),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),

          // ── Sticky footer ────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
            decoration: BoxDecoration(
              color: AppColors.background,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, -5),
                ),
              ],
            ),
            child: PrimaryButton(
              label: _selected == null ? 'Select a vehicle' : 'Continue',
              isLoading: _isLoading,
              enabled: _selected != null && !_isLoading,
              onTap: _continue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVehicleCard(_VehicleOption opt) {
    final isSelected = _selected == opt.type;

    return GestureDetector(
      onTap: _isLoading
          ? null
          : () {
              HapticFeedback.lightImpact();
              setState(() => _selected = opt.type);
            },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary.withOpacity(0.05)
              : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // Emoji icon in a box
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withOpacity(0.1)
                    : AppColors.surfaceAlt,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(opt.icon,
                    style: const TextStyle(fontSize: 26)),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(opt.title,
                      style: AppTextStyles.labelLarge.copyWith(
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textPrimary,
                      )),
                  const SizedBox(height: 2),
                  Text(opt.subtitle,
                      style: AppTextStyles.caption
                          .copyWith(color: AppColors.textSecondary)),
                  if (isSelected) ...[
                    const SizedBox(height: 6),
                    Text(opt.description,
                        style: AppTextStyles.caption
                            .copyWith(color: AppColors.textSecondary)),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isSelected ? AppColors.primary : Colors.transparent,
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary
                      : AppColors.border,
                  width: 2,
                ),
              ),
              child: isSelected
                  ? const Icon(Icons.check_rounded,
                      size: 13, color: AppColors.white)
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _VehicleOption {
  final DriverVehicleType type;
  final String title;
  final String subtitle;
  final String description;
  final String icon;

  const _VehicleOption({
    required this.type,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.icon,
  });
}