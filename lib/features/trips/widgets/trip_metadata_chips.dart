// lib/features/trips/widgets/trip_metadata_chips.dart
import 'package:flutter/material.dart';

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
    const primaryColor = Color(0xFF16A34A);

    return Row(
      children: [
        Expanded(
          child: _MetaChip(
            icon: Icons.schedule_rounded,
            label: eta,
            color: primaryColor,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetaChip(
            icon: Icons.route_rounded,
            label: '${distanceKm.toStringAsFixed(1)} km',
            color: Colors.blue,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _MetaChip(
            icon: Icons.payments_outlined,
            label: 'GHS ${fare.toStringAsFixed(2)}',
            color: Colors.orange,
          ),
        ),
      ],
    );
  }
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _MetaChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: color,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}