import 'package:flutter/material.dart';
import '../models/ride_request.dart';
import '../../../app/app_theme.dart';

enum RidePhase { enRouteToPickup, passengerOnboard, completed }

class ActiveRideScreen extends StatefulWidget {
  final RideRequest request;

  const ActiveRideScreen({super.key, required this.request});

  @override
  State<ActiveRideScreen> createState() => _ActiveRideScreenState();
}

class _ActiveRideScreenState extends State<ActiveRideScreen> {
  RidePhase _phase = RidePhase.enRouteToPickup;

  void _advancePhase() {
    setState(() {
      if (_phase == RidePhase.enRouteToPickup) {
        _phase = RidePhase.passengerOnboard;
      } else if (_phase == RidePhase.passengerOnboard) {
        _phase = RidePhase.completed;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_phase == RidePhase.completed) {
      return _CompletedScreen(
        fare: widget.request.fare,
        onDone: () => Navigator.popUntil(context, (r) => r.isFirst),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_phase == RidePhase.enRouteToPickup
            ? 'En Route to Pickup'
            : 'Ride in Progress'),
        backgroundColor: AppTheme.surface,
        leading: _phase == RidePhase.enRouteToPickup
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => Navigator.pop(context),
              )
            : null,
      ),
      body: Column(
        children: [
          // ── Map placeholder ──
          _MapPlaceholder(
            phase: _phase,
            pickupAddress: widget.request.pickupAddress,
            dropoffAddress: widget.request.dropoffAddress,
          ),

          // ── Passenger card ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _PassengerCard(request: widget.request, phase: _phase),
                  const SizedBox(height: 16),
                  _PhaseInfoCard(
                      request: widget.request, phase: _phase),
                  const SizedBox(height: 20),
                  // CTA button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _advancePhase,
                      icon: Icon(_phase == RidePhase.enRouteToPickup
                          ? Icons.person_pin_circle_rounded
                          : Icons.flag_rounded),
                      label: Text(_phase == RidePhase.enRouteToPickup
                          ? 'Arrived – Pick Up Passenger'
                          : 'Complete Ride'),
                      style: ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                        backgroundColor:
                            _phase == RidePhase.passengerOnboard
                                ? AppTheme.primaryDark
                                : AppTheme.primary,
                      ),
                    ),
                  ),
                  if (_phase == RidePhase.enRouteToPickup)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: () => _showCancelDialog(context),
                          icon: const Icon(Icons.cancel_outlined,
                              color: AppTheme.danger),
                          label: const Text('Cancel Ride',
                              style: TextStyle(color: AppTheme.danger)),
                          style: OutlinedButton.styleFrom(
                            side: const BorderSide(
                                color: AppTheme.danger),
                            padding: const EdgeInsets.symmetric(
                                vertical: 14),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCancelDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel this ride?'),
        content: const Text(
            'Frequent cancellations may affect your acceptance rate.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep ride'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text('Cancel',
                style: TextStyle(color: AppTheme.danger)),
          ),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _MapPlaceholder extends StatelessWidget {
  final RidePhase phase;
  final String pickupAddress;
  final String dropoffAddress;

  const _MapPlaceholder({
    required this.phase,
    required this.pickupAddress,
    required this.dropoffAddress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.15),
            AppTheme.primaryLight,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Stack(
        children: [
          // Fake grid lines
          CustomPaint(
            size: const Size(double.infinity, 220),
            painter: _GridPainter(),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.map_rounded,
                    size: 40, color: AppTheme.primary),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    phase == RidePhase.enRouteToPickup
                        ? '→ $pickupAddress'
                        : '→ $dropoffAddress',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primary.withValues(alpha: 0.07)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 30) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), paint);
    }
    for (double y = 0; y < size.height; y += 30) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter _) => false;
}

class _PassengerCard extends StatelessWidget {
  final RideRequest request;
  final RidePhase phase;

  const _PassengerCard({required this.request, required this.phase});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: AppTheme.primaryLight,
            child: Text(
              request.passengerName[0].toUpperCase(),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.passengerName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                RatingStars(rating: request.passengerRating),
              ],
            ),
          ),
          // Call button
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppTheme.primaryLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.phone_rounded,
                color: AppTheme.primary, size: 20),
          ),
          const SizedBox(width: 8),
          // Message button
          Container(
            width: 44,
            height: 44,
            decoration: const BoxDecoration(
              color: AppTheme.infoLight,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.chat_bubble_outline_rounded,
                color: AppTheme.info, size: 20),
          ),
        ],
      ),
    );
  }
}

class _PhaseInfoCard extends StatelessWidget {
  final RideRequest request;
  final RidePhase phase;

  const _PhaseInfoCard({required this.request, required this.phase});

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
        children: [
          InfoRow(
            icon: Icons.my_location_rounded,
            label: 'Pickup',
            value: request.pickupAddress,
            iconColor: AppTheme.primary,
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppTheme.divider),
          const SizedBox(height: 10),
          InfoRow(
            icon: Icons.location_on_rounded,
            label: 'Drop-off',
            value: request.dropoffAddress,
            iconColor: AppTheme.danger,
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppTheme.divider),
          const SizedBox(height: 10),
          InfoRow(
            icon: Icons.attach_money_rounded,
            label: 'Fare',
            value: 'GH₵ ${request.fare.toStringAsFixed(2)}',
            iconColor: AppTheme.primary,
          ),
          const SizedBox(height: 10),
          InfoRow(
            icon: Icons.straighten_rounded,
            label: 'Distance',
            value: '${request.distanceKm.toStringAsFixed(1)} km',
            iconColor: AppTheme.textSecondary,
          ),
        ],
      ),
    );
  }
}

class _CompletedScreen extends StatelessWidget {
  final double fare;
  final VoidCallback onDone;

  const _CompletedScreen({required this.fare, required this.onDone});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: const BoxDecoration(
                    color: AppTheme.primaryLight,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.check_circle_rounded,
                      size: 56, color: AppTheme.primary),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Ride Completed!',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Great job! Your earnings have\nbeen added to your wallet.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppTheme.primary.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      const Text(
                        'You earned',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppTheme.primaryDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'GH₵ ${fare.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.w900,
                          color: AppTheme.primary,
                          letterSpacing: -1,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onDone,
                    style: ElevatedButton.styleFrom(
                        padding:
                            const EdgeInsets.symmetric(vertical: 16)),
                    child: const Text('Back to Home'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color iconColor;

  const InfoRow({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    required this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: iconColor),
        const SizedBox(width: 12),
        SizedBox(
          width: 70,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppTheme.textSecondary,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.textPrimary,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}