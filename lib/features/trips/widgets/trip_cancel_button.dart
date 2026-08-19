// lib/features/trips/widgets/trip_cancel_button.dart
import 'package:flutter/material.dart';

class TripCancelButton extends StatelessWidget {
  final bool isLoading;
  final VoidCallback onTap;

  const TripCancelButton({
    super.key,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: isLoading ? null : onTap,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          side: BorderSide(color: Colors.red.withValues(alpha: 0.5)),
          foregroundColor: Colors.red,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.red,
                ),
              )
            : const Text(
                'Cancel Trip',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
      ),
    );
  }
}