// lib/features/trips/widgets/trip_passenger_card.dart
import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';

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

    return Row(
      children: [
        CircleAvatar(
          radius: 26,
          backgroundColor: AppTheme.primaryLight,
          backgroundImage: photoUrl != null ? NetworkImage(photoUrl!) : null,
          child: photoUrl == null
              ? Text(
                  initials.isEmpty ? 'P' : initials,
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryDark,
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
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 16,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(
                    Icons.star_rounded,
                    color: AppTheme.warning,
                    size: 16,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    rating > 0 ? rating.toStringAsFixed(1) : 'New',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (onCall != null && phone != null)
          IconButton(
            onPressed: onCall,
            tooltip: 'Call passenger',
            icon: const Icon(Icons.phone_rounded, size: 22),
            style: IconButton.styleFrom(
              foregroundColor: AppTheme.primaryDark,
              backgroundColor: AppTheme.primaryLight,
              minimumSize: const Size(48, 48),
              side: const BorderSide(color: AppTheme.primarySubtle),
            ),
          ),
      ],
    );
  }
}
