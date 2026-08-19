// lib/features/trips/widgets/trip_passenger_card.dart
import 'package:flutter/material.dart';

class TripPassengerCard extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double rating;
  final String? phone;
  final VoidCallback? onCall;

  const TripPassengerCard({
    super.key,
    required this.name,
    this.photoUrl,
    required this.rating,
    this.phone,
    this.onCall,
  });

  @override
  Widget build(BuildContext context) {
    final initials = name
        .trim()
        .split(' ')
        .map((p) => p.isEmpty ? '' : p[0])
        .take(2)
        .join()
        .toUpperCase();

    const primaryColor = Color(0xFF16A34A);

    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: primaryColor.withValues(alpha: 0.1),
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
          child: photoUrl == null
              ? Text(
                  initials.isEmpty ? 'P' : initials,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                    fontSize: 16,
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 15,
                ),
              ),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: Color(0xFFFFB74D),
                    size: 14,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    rating > 0 ? rating.toStringAsFixed(1) : 'New',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (onCall != null && phone != null)
          _IconAction(
            icon: Icons.phone_rounded,
            color: primaryColor,
            onTap: onCall!,
            tooltip: 'Call passenger',
          ),
      ],
    );
  }
}

class _IconAction extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final String? tooltip;

  const _IconAction({
    required this.icon,
    required this.color,
    required this.onTap,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
      ),
    );
  }
}