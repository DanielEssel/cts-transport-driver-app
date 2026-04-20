import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import 'package:cts_transport_driver_app/features/driver/models/driver_type.dart';
void main() {
  runApp(const DriverApp());
}

/// Standalone driver app entry point.
/// In production this is merged into the main RiderApp in main.dart —
/// the role is determined at signup and stored in the user profile.
/// This file is for isolated driver UI development only.
class DriverApp extends StatelessWidget {
  const DriverApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RideGo Driver',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Inter',
        primaryColor: AppColors.primary,
        scaffoldBackgroundColor: AppColors.background,
        useMaterial3: true,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          primary: AppColors.primary,
        ),
        appBarTheme: const AppBarTheme(
          elevation: 0,
          surfaceTintColor: Colors.transparent,
          backgroundColor: AppColors.background,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: CupertinoPageTransitionsBuilder(),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      ),
      // In production: initialRoute = AppRoutes.splash
      // Here we show the selector for dev/preview
      home: const DriverTypeSelector(),
    );
  }
}

// ─── Driver Type Selector ─────────────────────────────────────────────────────
// DEV ONLY — simulates the vehicle selection that happens at signup.
// In the real app:
//   role_selection_screen.dart  → picks hailing or delivery driver
//   driver_vehicle_setup_screen.dart → picks vehicle for delivery drivers
// This screen combines both steps for isolated driver testing.

class DriverTypeSelector extends StatelessWidget {
  const DriverTypeSelector({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Brand icon
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.directions_car_rounded,
                  color: AppColors.white,
                  size: 26,
                ),
              ),
              const SizedBox(height: 20),

              // Heading
              const Text(
                'What do you drive?',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Select your vehicle. This determines\nwhat requests you will receive.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 14,
                  color: AppColors.textSecondary,
                  height: 1.6,
                ),
              ),
              const SizedBox(height: 32),

              // ── Vehicle options ───────────────────────────────────────
              _VehicleCard(
                icon: Icons.two_wheeler_rounded,
                iconColor: AppColors.primary,
                title: 'Motorbike',
                subtitle: 'Ride hailing or parcel delivery',
                trailingWidget: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '2 options',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        color: AppColors.textTertiary,
                      ),
                    ),
                     SizedBox(width: 4),
                     Icon(Icons.keyboard_arrow_down_rounded,
                        color: AppColors.textSecondary, size: 18),
                  ],
                ),
                onTap: () => _showMotorbikeSheet(context),
              ),
              const SizedBox(height: 12),

              _VehicleCard(
                icon: Icons.electric_rickshaw_rounded,
                iconColor: AppColors.warning,
                title: 'Tricycle (Aboboya)',
                subtitle: 'Delivery only · Medium & Large parcels',
                badge: '5–100 kg',
                badgeColor: AppColors.warning,
                onTap: () => _launch(context, DriverType.aboboya),
              ),
              const SizedBox(height: 12),

              _VehicleCard(
                icon: Icons.local_shipping_rounded,
                iconColor: AppColors.error,
                title: 'Mini Truck',
                subtitle: 'Delivery only · Bulk cargo',
                badge: '100 kg+',
                badgeColor: AppColors.error,
                onTap: () => _launch(context, DriverType.miniTruck),
              ),

              const Spacer(),

              // Footer note
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.border),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.lock_rounded,
                        size: 14, color: AppColors.textTertiary),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Vehicle type can only be changed by contacting support.',
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
            ],
          ),
        ),
      ),
    );
  }

  // ── Motorbike purpose bottom sheet ────────────────────────────────────────
  void _showMotorbikeSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),

            const Text(
              'What will you use\nyour motorbike for?',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'This cannot be changed later without contacting support.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 20),

            _VehicleCard(
              icon: Icons.hail_rounded,
              iconColor: AppColors.primary,
              title: 'Ride Hailing',
              subtitle: 'Pick up and drop off passengers',
              badge: 'Passengers',
              badgeColor: AppColors.primary,
              onTap: () {
                Navigator.pop(context);
                _launch(context, DriverType.okadaHailing);
              },
            ),
            const SizedBox(height: 12),

            _VehicleCard(
              icon: Icons.inventory_2_rounded,
              iconColor: AppColors.success,
              title: 'Parcel Delivery',
              subtitle: 'Small parcels only · 0–5 kg',
              badge: '0–5 kg',
              badgeColor: AppColors.success,
              onTap: () {
                Navigator.pop(context);
                _launch(context, DriverType.okadaDelivery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  void _launch(BuildContext context, DriverType type) {
    // In production: DriverType is stored via provider/Bloc, then navigate:
    // Navigator.pushReplacement(
    //   context,
    //   MaterialPageRoute(builder: (_) => DriverRootShell(driverType: type)),
    // );

    // Dev preview — show resolved type as snackbar
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '${type.label}  ·  ${type.isHailing ? "Ride requests" : "Delivery: ${type.allowedWeightTiers.join(', ')} tiers"}',
          style: const TextStyle(fontFamily: 'Inter', fontSize: 13),
        ),
        backgroundColor: AppColors.darkNavy,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}

// ─── Vehicle Card ─────────────────────────────────────────────────────────────

class _VehicleCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? badge;
  final Color? badgeColor;
  final Widget? trailingWidget;
  final VoidCallback onTap;

  const _VehicleCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
    this.badgeColor,
    this.trailingWidget,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Icon box
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(width: 14),

            // Labels
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Trailing — badge, chevron, or custom widget
            if (trailingWidget != null)
              trailingWidget!
            else if (badge != null && badgeColor != null)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 9, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor!.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  badge!,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              )
            else
              const Icon(Icons.chevron_right_rounded,
                  color: AppColors.textTertiary, size: 18),
          ],
        ),
      ),
    );
  }
}