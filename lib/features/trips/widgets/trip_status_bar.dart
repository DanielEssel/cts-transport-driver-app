// lib/features/trips/widgets/trip_status_bar.dart
import 'package:flutter/material.dart';
import '../models/trip_model.dart';

class TripStatusBar extends StatelessWidget {
  final TripStatus status;
  final String eta;

  const TripStatusBar({
    super.key,
    required this.status,
    required this.eta,
  });

  @override
  Widget build(BuildContext context) {
    final (color, icon, label) = switch (status) {
      TripStatus.tripAccepted => (
          const Color(0xFF16A34A),
          Icons.directions_rounded,
          'Heading to pickup'
        ),
      TripStatus.driverArrived => (
          Colors.green,
          Icons.location_on_rounded,
          'Waiting at pickup'
        ),
      TripStatus.tripStarted => (
          Colors.blue,
          Icons.electric_bolt_rounded,
          'Trip in progress'
        ),
      TripStatus.completed => (
          Colors.purple,
          Icons.flag_rounded,
          'Trip completed'
        ),
      _ => (Colors.grey, Icons.info_rounded, status.displayName),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              eta,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}