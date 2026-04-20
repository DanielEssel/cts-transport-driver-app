// features/driver/presentation/driver_home_screen.dart

import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';
import '../../../app/app_routes.dart';
import '../../driver/models/driver_type.dart';

class DriverHomeScreen extends StatefulWidget {
  final DriverType driverType;

  const DriverHomeScreen({
    super.key,
    required this.driverType,
  });

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _isOnline = false;
  int _availableRequests = 5;
  double _todayEarnings = 125.50;
  double _totalEarnings = 2450.75;
  double _rating = 4.8;
  int _completedTrips = 156;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.backgroundColor,
      // Remove the app bar since DriverRootShell might provide it
      // Or keep it if you want - but remove the bottom navigation bar
      appBar: AppBar(
        backgroundColor: AppColors.backgroundColor,
        elevation: 0,
        leading: const Padding(
          padding: EdgeInsets.all(12.0),
          child: CircleAvatar(
            backgroundColor: AppColors.primaryLightColor,
            child: Icon(Icons.person, color: AppColors.backgroundColor),
          ),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Hello, Driver 👋',
              style: AppTextStyles.driverGreeting,
            ),
            Text(
              _isOnline ? 'You are Online' : 'You are Offline',
              style: AppTextStyles.riderStatus.copyWith(
                color: _isOnline ? AppColors.successColor : AppColors.textSecondaryColor,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined, 
              color: AppColors.textPrimaryColor),
            onPressed: () {},
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildOnlineToggle(),
              const SizedBox(height: 24),
              _buildStatsRow(),
              const SizedBox(height: 24),
              _buildAvailableRequestsSection(),
              const SizedBox(height: 24),
              _buildEarningsSection(),
              const SizedBox(height: 24),
              _buildQuickActionsGrid(),
            ],
          ),
        ),
      ),
      // REMOVED: bottomNavigationBar - this is now handled by DriverRootShell
    );
  }

  // ============================================
  // ONLINE/OFFLINE TOGGLE
  // ============================================
  Widget _buildOnlineToggle() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: _isOnline 
            ? [AppColors.successColor, const Color(0xFF45B649)]
            : [AppColors.textDisabledColor, const Color(0xFFA9A9A9)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _isOnline 
              ? AppColors.successColor.withValues(alpha: 0.3)
              : AppColors.textDisabledColor.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _isOnline ? 'You\'re Online' : 'You\'re Offline',
                style: AppTextStyles.heading3.copyWith(
                  color: AppColors.backgroundColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _isOnline 
                  ? 'Ready to accept requests' 
                  : 'Tap to start accepting requests',
                style: AppTextStyles.subtitle.copyWith(
                  color: AppColors.backgroundColor,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: () {
              setState(() => _isOnline = !_isOnline);
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(_isOnline ? 'You are now Online' : 'You are now Offline'),
                  backgroundColor: _isOnline ? AppColors.successColor : AppColors.errorColor,
                  duration: const Duration(seconds: 2),
                ),
              );
            },
            child: Container(
              width: 60,
              height: 60,
              decoration: const BoxDecoration(
                color: AppColors.backgroundColor,
                shape: BoxShape.circle,
              ),
              child: Icon(
                _isOnline ? Icons.power_settings_new : Icons.power_off,
                color: _isOnline ? AppColors.successColor : AppColors.textDisabledColor,
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================
  // STATS ROW
  // ============================================
  Widget _buildStatsRow() {
    return Row(
      children: [
        Expanded(
          child: _StatCard(
            label: 'Rating',
            value: '$_rating ⭐',
            icon: Icons.star,
            color: const Color(0xFFFFB74D),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _StatCard(
            label: 'Trips',
            value: '$_completedTrips',
            icon: Icons.directions_car,
            color: AppColors.primaryColor,
          ),
        ),
      ],
    );
  }

  // ============================================
  // AVAILABLE REQUESTS SECTION
  // ============================================
  Widget _buildAvailableRequestsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
           const Text(
              'Available Requests',
              style: AppTextStyles.heading4,
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '$_availableRequests new',
                style: AppTextStyles.caption.copyWith(
                  color: AppColors.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_isOnline)
          ...[
            _RequestCard(
              fromLocation: '123 Business Street',
              toLocation: '456 Main Avenue',
              fare: 'GHS 25.50',
              distance: '5.2 km',
              time: '12 min',
              passengerName: 'John Doe',
              type: 'Ride',
              onAccept: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Request accepted!'),
                    backgroundColor: AppColors.successColor,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _RequestCard(
              fromLocation: '789 Park Lane',
              toLocation: '321 Commerce Street',
              fare: 'GHS 18.00',
              distance: '3.8 km',
              time: '8 min',
              passengerName: 'Jane Smith',
              type: 'Delivery',
              onAccept: () {
                ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(
                    content: Text('Request accepted!'),
                    backgroundColor: AppColors.successColor,
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
          ]
        else
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 32.0),
              child: Column(
                children: [
                const  Icon(Icons.power_off, 
                    size: 48, color: AppColors.textDisabledColor),
                 const SizedBox(height: 12),
                  Text(
                    'Go Online to see requests',
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  // ============================================
  // EARNINGS SECTION
  // ============================================
  Widget _buildEarningsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today\'s Earnings',
          style: AppTextStyles.heading4,
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundLightColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GHS $_todayEarnings',
                    style: AppTextStyles.driverStatsValue,
                  ),
                 const Text(
                    'Today\'s Earnings',
                    style: AppTextStyles.driverStats,
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.earnings),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child:const Text(
                  'View Details',
                  style: AppTextStyles.buttonSmall,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.backgroundColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.borderColor),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'GHS $_totalEarnings',
                    style: AppTextStyles.driverStatsValue,
                  ),
                  const Text(
                    'Total Balance',
                    style: AppTextStyles.driverStats,
                  ),
                ],
              ),
              ElevatedButton(
                onPressed: () => Navigator.pushNamed(context, AppRoutes.withdrawal),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF4CAF50),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: const Text(
                  'Withdraw',
                  style: AppTextStyles.buttonSmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============================================
  // QUICK ACTIONS GRID
  // ============================================
  Widget _buildQuickActionsGrid() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
       const Text(
          'Quick Actions',
          style: AppTextStyles.heading4,
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.history,
                label: 'Trip History',
                onTap: () => Navigator.pushNamed(context, AppRoutes.tripHistory),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.person,
                label: 'Profile',
                onTap: () {
                  // Navigate to profile screen
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.wallet_giftcard,
                label: 'My Wallet',
                onTap: () => Navigator.pushNamed(context, AppRoutes.driverWallet),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _ActionButton(
                icon: Icons.settings,
                label: 'Settings',
                onTap: () {
                  // Navigate to settings screen
                },
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================
// CUSTOM WIDGETS (keep all these as they are)
// ============================================

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 12),
          Text(label, style: AppTextStyles.caption),
          Text(value, style: AppTextStyles.driverStatsValue.copyWith(color: color)),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final String fromLocation;
  final String toLocation;
  final String fare;
  final String distance;
  final String time;
  final String passengerName;
  final String type;
  final VoidCallback onAccept;

  const _RequestCard({
    required this.fromLocation,
    required this.toLocation,
    required this.fare,
    required this.distance,
    required this.time,
    required this.passengerName,
    required this.type,
    required this.onAccept,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.backgroundLightColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  type,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                fare,
                style: AppTextStyles.cardPrice,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
             const Icon(Icons.person_outline, 
                color: AppColors.textSecondaryColor, size: 16),
             const SizedBox(width: 6),
              Text(passengerName, style: AppTextStyles.bodySmall),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
             const Icon(Icons.location_on, 
                color: AppColors.primaryColor, size: 16),
             const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(fromLocation, 
                      style: AppTextStyles.bodySmall, 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 8),
                    Container(
                      width: 2,
                      height: 20,
                      color: AppColors.textDisabledColor,
                    ),
                    const SizedBox(height: 8),
                    Text(toLocation, 
                      style: AppTextStyles.bodySmall, 
                      maxLines: 1, 
                      overflow: TextOverflow.ellipsis),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
             const Icon(Icons.timer,
                color: AppColors.successColor, size: 16),
             const SizedBox(width: 6),
              Text('$distance • $time', 
                style: AppTextStyles.caption),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () {},
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: AppColors.primaryColor),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'Reject',
                    style: AppTextStyles.buttonSmall.copyWith(
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: onAccept,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.successColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: const Text('Accept', style: AppTextStyles.buttonSmall),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.backgroundLightColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.borderColor),
        ),
        child: Column(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primaryColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, color: AppColors.primaryColor),
            ),
            const SizedBox(height: 8),
            Text(label, 
              style: AppTextStyles.quickActionLabel,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}