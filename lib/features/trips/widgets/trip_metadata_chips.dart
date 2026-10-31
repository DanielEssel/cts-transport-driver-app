// lib/features/trips/widgets/trip_metadata_chips.dart
import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

/// Time, distance and fare for the current ride, as three equal tiles.
/// Neutral on purpose: blue and orange identify delivery and gas.
class TripMetadataChips extends StatelessWidget {
  final String eta;
  final double distanceKm;
  final double fare;

  const TripMetadataChips({
    super.key,
    required this.eta,
    required this.distanceKm,
    required this.fare,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _MetaChip(
            icon: Icons.schedule_rounded,
            caption: 'Time',
            label: eta,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetaChip(
            icon: Icons.route_rounded,
            caption: 'Distance',
            label: '${distanceKm.toStringAsFixed(1)} km',
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetaChip(
            icon: Icons.payments_outlined,
            caption: 'Fare',
            label: 'GHS ${fare.toStringAsFixed(2)}',
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String caption;
  final String label;

  const _MetaChip({
    required this.icon,
    required this.caption,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.divider),
      ),
      child: Column(
        children: [
          Icon(icon, size: 18, color: AppTheme.primaryDark),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          Text(
            caption,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
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
