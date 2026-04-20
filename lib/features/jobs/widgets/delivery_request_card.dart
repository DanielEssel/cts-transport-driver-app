import 'package:flutter/material.dart';
import '../../jobs/models/ride_request.dart';
import '../../../app/app_theme.dart';
import '../../jobs/models/delivery_request.dart';

class DeliveryRequestCard extends StatelessWidget {
  final DeliveryRequest request;
  final VoidCallback onAccept;
  final VoidCallback onDecline;
  final bool showFragileHelpers; // true for aboboya & miniTruck

  const DeliveryRequestCard({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onDecline,
    this.showFragileHelpers = false,
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
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: parcel type + countdown ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      request.parcelType.icon,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            request.parcelType.label,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          WeightTierBadge(
                              label: request.weightTier.label),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'From ${request.senderName}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                CountdownRing(seconds: 30, onExpired: onDecline),
              ],
            ),
          ),

          // ── Photo thumbnail (if available) ──
          if (request.photoUrl != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(
                  request.photoUrl!,
                  height: 90,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Container(
                    height: 90,
                    color: AppTheme.divider,
                    child: const Center(
                      child: Icon(Icons.image_not_supported_outlined,
                          color: AppTheme.textHint),
                    ),
                  ),
                ),
              ),
            ),

          // ── Fragile + Helpers flags (aboboya & miniTruck) ──
          if (showFragileHelpers &&
              (request.isFragile || request.needsHelpers))
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Wrap(
                spacing: 8,
                children: [
                  if (request.isFragile)
                   const  _FlagChip(
                      icon: Icons.warning_amber_rounded,
                      label: 'Fragile',
                      color: AppTheme.warning,
                    ),
                  if (request.needsHelpers)
                   const  _FlagChip(
                      icon: Icons.people_rounded,
                      label: 'Helpers needed',
                      color: AppTheme.info,
                    ),
                ],
              ),
            ),

          const Divider(height: 1, color: AppTheme.divider),

          // ── Fare row ──
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
                const SizedBox(width: 10),
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
                  icon: Icons.scale_rounded,
                  label: request.weightTier.weightRange,
                ),
              ],
            ),
          ),

          // ── Route ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: RouteAddressColumn(
              pickup: request.pickupAddress,
              dropoff: request.dropoffAddress,
            ),
          ),

          // ── Special instructions ──
          if (request.specialInstructions != null &&
              request.specialInstructions!.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.warningLight,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: AppTheme.warning.withValues(alpha: 0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline_rounded,
                        size: 14, color: AppTheme.warning),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        request.specialInstructions!,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.warning,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ── Action buttons ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
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
                    child: const Text('Accept Delivery'),
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

class _FlagChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _FlagChip(
      {required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
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
        color: c.withValues(alpha: 0.08),
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