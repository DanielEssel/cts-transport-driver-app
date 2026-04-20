import 'package:flutter/material.dart';
import '../../jobs/models/ride_request.dart';
import '../../../app/app_theme.dart';

class RideRequestCard extends StatelessWidget {
  final RideRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  const RideRequestCard({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onDecline,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.cardBackground,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.divider),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header row ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                // Avatar
                CircleAvatar(
                  radius: 22,
                  backgroundColor: AppTheme.primaryLight,
                  child: Text(
                    request.passengerName.isNotEmpty
                        ? request.passengerName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        request.passengerName,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          RatingStars(rating: request.passengerRating),
                          const SizedBox(width: 4),
                          Text(
                            request.passengerRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                // Countdown
                CountdownRing(seconds: 30, onExpired: onDecline),
              ],
            ),
          ),

          // ── Divider ──
          const Divider(height: 1, color: AppTheme.divider),

          // ── Fare + meta chips ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Text(
                  'GH₵ ${request.fare.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.primary,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(width: 12),
                _MetaChip(
                  icon: Icons.straighten_rounded,
                  label: '${request.distanceKm.toStringAsFixed(1)} km',
                ),
                const SizedBox(width: 6),
                _MetaChip(
                  icon: Icons.access_time_rounded,
                  label: '${request.etaToPickupMinutes} min away',
                  color: request.etaToPickupMinutes <= 3
                      ? AppTheme.primary
                      : AppTheme.warning,
                ),
                const SizedBox(width: 6),
                _MetaChip(
                  icon: Icons.person_rounded,
                  label:
                      '${request.seatCount} seat${request.seatCount > 1 ? 's' : ''}',
                ),
              ],
            ),
          ),

          // ── Route ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: RouteAddressColumn(
              pickup: request.pickupAddress,
              dropoff: request.dropoffAddress,
            ),
          ),

          // ── Action buttons ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: onDecline,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.danger,
                      side: const BorderSide(color: AppTheme.danger),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                    ),
                    child: const Text('Decline'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: onAccept,
                    child: const Text('Accept Ride'),
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

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color? color;

  const _MetaChip(
      {required this.icon, required this.label, this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? AppTheme.textSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: c),
          const SizedBox(width: 3),
          Text(
            label,
            style:
                TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: c),
          ),
        ],
      ),
    );
  }
}