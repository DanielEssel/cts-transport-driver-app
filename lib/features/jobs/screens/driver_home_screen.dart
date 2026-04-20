import 'package:flutter/material.dart';
import '../../driver/models/driver_type.dart';
import '../../jobs/models/ride_request.dart';
import '../../jobs/models/delivery_request.dart';
import '../data/mock_data.dart';
import '../widgets/ride_request_card.dart';
import '../widgets/delivery_request_card.dart';
import '../../../app/app_theme.dart';
import 'active_ride_screen.dart';
import 'active_delivery_screen.dart';

class DriverHomeScreen extends StatefulWidget {
  final DriverType driverType;

  const DriverHomeScreen({super.key, required this.driverType});

  @override
  State<DriverHomeScreen> createState() => _DriverHomeScreenState();
}

class _DriverHomeScreenState extends State<DriverHomeScreen> {
  bool _isOnline = true;
  late List<RideRequest> _rideRequests;
  late List<DeliveryRequest> _deliveryRequests;

  // Stats for today
  final int _todayTrips = 7;
  final double _todayEarnings = 182.50;

  @override
  void initState() {
    super.initState();
    _loadRequests();
  }

  void _loadRequests() {
    _rideRequests = MockDataService.getRideRequestsFor(widget.driverType);
    _deliveryRequests = MockDataService.getDeliveryRequestsFor(widget.driverType);
  }

  void _onToggleOnline() {
    setState(() {
      _isOnline = !_isOnline;
    });
  }

  void _removeRideRequest(String id) {
    setState(() {
      _rideRequests.removeWhere((r) => r.id == id);
    });
  }

  void _removeDeliveryRequest(String id) {
    setState(() {
      _deliveryRequests.removeWhere((r) => r.id == id);
    });
  }

  void _acceptRide(RideRequest request) {
    _removeRideRequest(request.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveRideScreen(request: request),
      ),
    );
  }

  void _acceptDelivery(DeliveryRequest request) {
    _removeDeliveryRequest(request.id);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ActiveDeliveryScreen(
          request: request,
          driverType: widget.driverType,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        slivers: [
          // ── App Bar ──────────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.surface,
            elevation: 0,
            title: Row(
              children: [
                Text(
                  widget.driverType.vehicleIcon,
                  style: const TextStyle(fontSize: 20),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Good morning, Kwesi 👋',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    Text(
                      widget.driverType.displayName,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            actions: [
              Stack(
                children: [
                  IconButton(
                    icon: const Icon(Icons.notifications_outlined),
                    color: AppTheme.textPrimary,
                    onPressed: () {},
                  ),
                  Positioned(
                    right: 10,
                    top: 10,
                    child: Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: AppTheme.danger,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // ── Online/Offline Banner ─────────────────────────────────────────
          SliverToBoxAdapter(
            child: OnlineBanner(
              isOnline: _isOnline,
              onToggle: _onToggleOnline,
            ),
          ),

          // ── Today's Stats ─────────────────────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: StatCard(
                      label: "Today's Trips",
                      value: '$_todayTrips',
                      icon: Icons.route_rounded,
                      color: AppTheme.primary,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: StatCard(
                      label: "Today's Earnings",
                      value: 'GH₵ ${_todayEarnings.toStringAsFixed(2)}',
                      icon: Icons.account_balance_wallet_rounded,
                      color: AppTheme.accent,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Request list or empty state ───────────────────────────────────
          if (!_isOnline)
            SliverFillRemaining(child: _offlineState())
          else if (widget.driverType.isRide)
            _rideRequestSliver()
          else
            _deliveryRequestSliver(),
        ],
      ),
    );
  }

  Widget _offlineState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppTheme.divider,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.wifi_off_rounded,
                size: 36, color: AppTheme.textHint),
          ),
          const SizedBox(height: 16),
          const Text(
            'You are offline',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Toggle online to start receiving\nride and delivery requests.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rideRequestSliver() {
    if (_rideRequests.isEmpty) {
      return SliverFillRemaining(child: _emptyState('ride'));
    }
    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SectionHeader(
            title: '${_rideRequests.length} Incoming Ride${_rideRequests.length > 1 ? 's' : ''}',
          ),
        ),
        ..._rideRequests.map((r) => RideRequestCard(
              request: r,
              onAccept: () => _acceptRide(r),
              onDecline: () => _removeRideRequest(r.id),
            )),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _deliveryRequestSliver() {
    if (_deliveryRequests.isEmpty) {
      return SliverFillRemaining(child: _emptyState('delivery'));
    }
    final showFlags = widget.driverType == DriverType.aboboya ||
        widget.driverType == DriverType.miniTruck;
    return SliverList(
      delegate: SliverChildListDelegate([
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: SectionHeader(
            title: '${_deliveryRequests.length} Incoming Deliver${_deliveryRequests.length > 1 ? 'ies' : 'y'}',
          ),
        ),
        ..._deliveryRequests.map((r) => DeliveryRequestCard(
              request: r,
              onAccept: () => _acceptDelivery(r),
              onDecline: () => _removeDeliveryRequest(r.id),
              showFragileHelpers: showFlags,
            )),
        const SizedBox(height: 16),
      ]),
    );
  }

  Widget _emptyState(String type) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: const BoxDecoration(
              color: AppTheme.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.search_rounded,
                size: 36, color: AppTheme.primary),
          ),
          const SizedBox(height: 16),
          Text(
            'Looking for $type requests…',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'New requests will appear here\nas customers book near you.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Online Banner Widget ──────────────────────────────────────────────────────
class OnlineBanner extends StatelessWidget {
  final bool isOnline;
  final VoidCallback onToggle;

  const OnlineBanner({
    super.key,
    required this.isOnline,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isOnline
              ? [AppTheme.primary, AppTheme.primaryDark]
              : [AppTheme.textSecondary, AppTheme.textHint],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (isOnline ? AppTheme.primary : AppTheme.textSecondary)
                .withValues(alpha: 0.3),
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
                isOnline ? 'You are Online' : 'You are Offline',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isOnline
                    ? 'Ready to accept requests'
                    : 'Tap to go online',
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.white70,
                ),
              ),
            ],
          ),
          GestureDetector(
            onTap: onToggle,
            child: Container(
              width: 50,
              height: 50,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
              child: Icon(
                isOnline ? Icons.power_settings_new : Icons.power_off,
                color: isOnline ? AppTheme.primary : AppTheme.textSecondary,
                size: 28,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Stat Card Widget ──────────────────────────────────────────────────────────
class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const StatCard({
    super.key,
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
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section Header Widget ─────────────────────────────────────────────────────
class SectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;

  const SectionHeader({
    super.key,
    required this.title,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppTheme.textPrimary,
          ),
        ),
        if (trailing != null)
          Text(
            trailing!,
            style: const TextStyle(
              fontSize: 13,
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }
}