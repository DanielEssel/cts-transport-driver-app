// lib/features/trips/presentation/trip_flow_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:cts_transport_driver_app/core/services/marker_service.dart';

import '../models/trip_model.dart';
import 'accepted_trip_screen.dart';
import 'arrived_trip_screen.dart';
import 'active_trip_screen.dart';
import 'trip_completed_screen.dart';

class TripFlowScreen extends StatefulWidget {
  final String tripId;

  const TripFlowScreen({super.key, required this.tripId});

  @override
  State<TripFlowScreen> createState() => _TripFlowScreenState();
}

class _TripFlowScreenState extends State<TripFlowScreen> {
  final _db = FirebaseFirestore.instance;
  TripModel? _trip;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTrip();
  }

  Future<void> _loadTrip() async {
    try {
      // Warm up markers while loading
      await MarkerService.instance.warmUp(context);

      final doc = await _db.collection('trips').doc(widget.tripId).get();
      if (!doc.exists || !mounted) return;

      final trip = TripModel.fromFirestore(doc);
      setState(() {
        _trip = trip;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('❌ TripFlowScreen _loadTrip failed: $e');
      if (mounted) {
        setState(() => _isLoading = false);
        _showError('Could not load trip details.');
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red[700],
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          margin: const EdgeInsets.all(16),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Color(0xFFF8FAF9),
        body: Center(
          child: CircularProgressIndicator(
            color: Color(0xFF16A34A),
          ),
        ),
      );
    }

    if (_trip == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF8FAF9),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Trip not found',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                'This trip may have been cancelled or doesn\'t exist.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: _db.collection('trips').doc(widget.tripId).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _buildErrorScreen('Error loading trip: ${snapshot.error}');
        }

        if (!snapshot.hasData || !snapshot.data!.exists) {
          return _buildErrorScreen('Trip no longer exists.');
        }

        final trip = TripModel.fromFirestore(snapshot.data!);

        // Handle cancelled states
        if (trip.status == TripStatus.cancelledByDriver ||
            trip.status == TripStatus.cancelledByPassenger) {
          return _buildCancelledScreen(trip);
        }

        // Render appropriate screen based on trip status
        return _buildTripScreen(trip);
      },
    );
  }

  Widget _buildTripScreen(TripModel trip) {
    switch (trip.status) {
      case TripStatus.tripAccepted:
        return AcceptedTripScreen(
          tripId: widget.tripId,
          trip: trip,
        );

      case TripStatus.driverArrived:
        return ArrivedTripScreen(
          tripId: widget.tripId,
          trip: trip,
        );

      case TripStatus.tripStarted:
        return ActiveTripScreen(
          tripId: widget.tripId,
          trip: trip,
        );

      case TripStatus.completed:
        return TripCompletedScreen(
          tripId: widget.tripId,
          trip: trip,
        );

      default:
        return _buildErrorScreen('Unknown trip status: ${trip.status}');
    }
  }

  Widget _buildErrorScreen(String message) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCancelledScreen(TripModel trip) {
    final isDriverCancelled = trip.status == TripStatus.cancelledByDriver;
    final message = isDriverCancelled
        ? 'You cancelled this trip.'
        : 'Passenger cancelled this trip.';

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAF9),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.cancel_rounded,
                size: 64,
                color: isDriverCancelled ? Colors.orange : Colors.red,
              ),
              const SizedBox(height: 16),
              Text(
                'Trip Cancelled',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Colors.grey[600],
                    ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF16A34A),
                ),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}