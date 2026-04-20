import 'package:flutter/material.dart';
import '../../../driver/models/driver_type.dart';
import '../../../../app/app_theme.dart';

class DriverProfileScreen extends StatelessWidget {
  final DriverType driverType;

  const DriverProfileScreen({super.key, required this.driverType});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppTheme.surface,
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text('Edit',
                style: TextStyle(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w600,
                )),
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // ── Header / Avatar ──
            Container(
              width: double.infinity,
              color: AppTheme.surface,
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 28),
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                     const  CircleAvatar(
                        radius: 52,
                        backgroundColor: AppTheme.primaryLight,
                        child: Text(
                          'KA',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.primary,
                          ),
                        ),
                      ),
                      Container(
                        width: 32,
                        height: 32,
                        decoration: const BoxDecoration(
                          color: AppTheme.primary,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.camera_alt_rounded,
                            color: Colors.white, size: 16),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    'Kwesi Asante',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        driverType.vehicleIcon,
                        style: const TextStyle(fontSize: 16),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        driverType.displayName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  // Rating + trips
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.background,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _StatBubble(
                            value: '4.8',
                            label: 'Rating',
                            icon: Icons.star_rounded,
                            iconColor: AppTheme.accent),
                         SizedBox(width: 28),
                        _StatBubble(
                            value: '847',
                            label: 'Trips',
                            icon: Icons.route_rounded,
                            iconColor: AppTheme.primary),
                         SizedBox(width: 28),
                        _StatBubble(
                            value: '98%',
                            label: 'Acceptance',
                            icon: Icons.thumb_up_rounded,
                            iconColor: AppTheme.primary),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Vehicle Info ──
            _Section(
              title: 'Vehicle Information',
              children: [
                _ProfileRow(
                  icon: Icons.directions_car_rounded,
                  label: 'Vehicle Type',
                  value: driverType.displayName,
                ),
                const _ProfileRow(
                  icon: Icons.pin_rounded,
                  label: 'Plate Number',
                  value: 'GR 1234-22',
                ),
                const _ProfileRow(
                  icon: Icons.palette_rounded,
                  label: 'Color',
                  value: 'Red',
                ),
               const  _ProfileRow(
                  icon: Icons.calendar_month_rounded,
                  label: 'Year',
                  value: '2020',
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Allowed weight tiers ──
            if (driverType.isDelivery)
              _Section(
                title: 'Allowed Delivery Tiers',
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: driverType.allowedWeightTiers
                        .map((t) => WeightTierBadge(label: t.label))
                        .toList(),
                  ),
                  const SizedBox(height: 4),
                ],
              ),

            if (driverType.isDelivery) const SizedBox(height: 12),

            // ── Documents ──
           const _Section(
              title: 'Documents',
              children: [
                _DocumentRow(
                  label: "Driver's License",
                  status: 'verified',
                  expiry: 'Expires Dec 2026',
                ),
                _DocumentRow(
                  label: 'Vehicle Insurance',
                  status: 'verified',
                  expiry: 'Expires Mar 2025',
                ),
                _DocumentRow(
                  label: 'Road Worthiness',
                  status: 'expiring',
                  expiry: 'Expires Apr 2025',
                ),
                _DocumentRow(
                  label: 'DVLA Certificate',
                  status: 'verified',
                  expiry: 'Expires Jun 2026',
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Account ──
            const _Section(
              title: 'Account',
              children: [
                _ProfileRow(
                  icon: Icons.phone_rounded,
                  label: 'Phone',
                  value: '+233 24 567 8901',
                ),
                _ProfileRow(
                  icon: Icons.email_rounded,
                  label: 'Email',
                  value: 'kwesi.asante@email.com',
                ),
                _ProfileRow(
                  icon: Icons.location_city_rounded,
                  label: 'City',
                  value: 'Accra, Ghana',
                ),
              ],
            ),

            const SizedBox(height: 12),

            // ── Settings & Actions ──
            _Section(
              title: 'Settings',
              children: [
                _ActionRow(
                  icon: Icons.notifications_rounded,
                  label: 'Notifications',
                  onTap: () {},
                ),
                _ActionRow(
                  icon: Icons.help_outline_rounded,
                  label: 'Help & Support',
                  onTap: () {},
                ),
                _ActionRow(
                  icon: Icons.privacy_tip_rounded,
                  label: 'Privacy Policy',
                  onTap: () {},
                ),
                _ActionRow(
                  icon: Icons.logout_rounded,
                  label: 'Sign Out',
                  onTap: () {},
                  color: AppTheme.danger,
                ),
              ],
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.surface,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _ProfileRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class _DocumentRow extends StatelessWidget {
  final String label;
  final String status; // 'verified' | 'expiring' | 'expired' | 'pending'
  final String expiry;

  const _DocumentRow({
    required this.label,
    required this.status,
    required this.expiry,
  });

  Color get _color {
    switch (status) {
      case 'verified':
        return AppTheme.primary;
      case 'expiring':
        return AppTheme.warning;
      case 'expired':
        return AppTheme.danger;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData get _icon {
    switch (status) {
      case 'verified':
        return Icons.check_circle_rounded;
      case 'expiring':
        return Icons.warning_rounded;
      case 'expired':
        return Icons.cancel_rounded;
      default:
        return Icons.hourglass_empty_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
        const  Icon(Icons.description_rounded,
              size: 18, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  expiry,
                  style: TextStyle(
                    fontSize: 12,
                    color: status == 'expiring'
                        ? AppTheme.warning
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Icon(_icon, size: 20, color: _color),
        ],
      ),
    );
  }
}

class _ActionRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;

  const _ActionRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textPrimary;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Row(
          children: [
            Icon(icon, size: 18, color: c),
            const SizedBox(width: 12),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: c,
              ),
            ),
            const Spacer(),
          const  Icon(Icons.chevron_right_rounded,
                size: 18, color: AppTheme.textHint),
          ],
        ),
      ),
    );
  }
}

class _StatBubble extends StatelessWidget {
  final String value;
  final String label;
  final IconData icon;
  final Color iconColor;

  const _StatBubble({
    required this.value,
    required this.label,
    required this.icon,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: iconColor, size: 18),
        const SizedBox(height: 4),
        Text(
          value,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimary,
          ),
        ),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            color: AppTheme.textSecondary,
          ),
        ),
      ],
    );
  }
}

// Add this class after _StatBubble class
class WeightTierBadge extends StatelessWidget {
  final String label;

  const WeightTierBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (label.toLowerCase()) {
      case 'small':
        color = const Color(0xFF4CAF50);
        break;
      case 'medium':
        color = const Color(0xFF2196F3);
        break;
      case 'large':
        color = const Color(0xFFFF9800);
        break;
      case 'bulk':
        color = const Color(0xFFE53935);
        break;
      default:
        color = AppTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}