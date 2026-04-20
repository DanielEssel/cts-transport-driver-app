// core/widgets/request_card_components.dart

import 'package:flutter/material.dart';
import '../../../app/app_theme.dart';

class CountdownRing extends StatefulWidget {
  final int seconds;
  final VoidCallback onExpired;

  const CountdownRing({
    super.key,
    required this.seconds,
    required this.onExpired,
  });

  @override
  State<CountdownRing> createState() => _CountdownRingState();
}

class _CountdownRingState extends State<CountdownRing>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late int _remainingSeconds;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.seconds;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(seconds: widget.seconds),
    )..forward();
    
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onExpired();
      }
    });

    // Update remaining seconds every second
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (mounted && _remainingSeconds > 0) {
        setState(() {
          _remainingSeconds--;
        });
        return true;
      }
      return false;
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 44,
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: _controller.value,
            strokeWidth: 2.5,
            backgroundColor: AppTheme.divider,
            valueColor: AlwaysStoppedAnimation<Color>(
              _remainingSeconds <= 10 ? AppTheme.danger : AppTheme.primary,
            ),
          ),
          Text(
            '$_remainingSeconds',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _remainingSeconds <= 10 ? AppTheme.danger : AppTheme.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

class WeightTierBadge extends StatelessWidget {
  final String label;

  const WeightTierBadge({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    Color color;
    switch (label.toLowerCase()) {
      case 'small':
        color = const Color(0xFF4CAF50);
        break;
      case 'medium':
        color = const Color(0xFF2196F3);
        break;
      case 'large':
        color = const Color(0xFFFF9800);
        break;
      case 'bulk':
        color = const Color(0xFFE53935);
        break;
      default:
        color = AppTheme.textSecondary;
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class RatingStars extends StatelessWidget {
  final double rating;

  const RatingStars({super.key, required this.rating});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(5, (index) {
        if (index < rating.floor()) {
          return const Icon(Icons.star, size: 12, color: AppTheme.warning);
        } else if (index < rating && rating - index > 0.5) {
          return const Icon(Icons.star_half, size: 12, color: AppTheme.warning);
        } else {
          return const Icon(Icons.star_border, size: 12, color: AppTheme.warning);
        }
      }),
    );
  }
}

class RouteAddressColumn extends StatelessWidget {
  final String pickup;
  final String dropoff;

  const RouteAddressColumn({
    super.key,
    required this.pickup,
    required this.dropoff,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              child: const Icon(Icons.circle, size: 8, color: AppTheme.successColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                pickup,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textPrimary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Container(
            width: 1.5,
            height: 20,
            color: AppTheme.divider,
          ),
        ),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              margin: const EdgeInsets.only(top: 4),
              child: const Icon(Icons.location_on, size: 8, color: AppTheme.danger),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                dropoff,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.textSecondary,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// features/jobs/models/ride_request.dart

class RideRequest {
  final String id;
  final String passengerName;
  final double passengerRating;
  final String pickupAddress;
  final String dropoffAddress;
  final int etaToPickupMinutes;
  final int seatCount;
  final double fare;
  final double distanceKm;
  final DateTime requestedAt;

  RideRequest({
    required this.id,
    required this.passengerName,
    required this.passengerRating,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.etaToPickupMinutes,
    required this.seatCount,
    required this.fare,
    required this.distanceKm,
    required this.requestedAt,
  });
}