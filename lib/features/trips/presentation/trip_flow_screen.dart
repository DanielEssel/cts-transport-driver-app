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

  // Created once so rebuilds don't resubscribe. The live stream is the only
  // source of truth — no separate one-off fetch before it.
  late final Stream<DocumentSnapshot<Map<String, dynamic>>> _tripStream =
      _db.collection('trips').doc(widget.tripId).snapshots();

  bool _markersReady = false;

  @override
  void initState() {
    super.initState();
    // Normally already warmed from the home screen; this is a no-op then.
    MarkerService.instance.warmUp(context).whenComplete(() {
      if (mounted) setState(() => _markersReady = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _tripStream,
      builder: (context, snapshot) {
        final Widget child;
        final Object key;

        if (snapshot.hasError) {
          key = 'error';
          child = _buildErrorScreen('Could not load trip details.');
        } else if (!snapshot.hasData || !_markersReady) {
          // Still waiting for the first snapshot — loading, not an error.
          key = 'loading';
          child = _buildLoadingScreen();
        } else if (!snapshot.data!.exists) {
          key = 'missing';
          child = _buildErrorScreen(
              'This trip may have been cancelled or doesn\'t exist.');
        } else {
          final trip = TripModel.fromFirestore(snapshot.data!);
          key = trip.status;
          child = (trip.status == TripStatus.cancelledByDriver ||
                  trip.status == TripStatus.cancelledByPassenger)
              ? _buildCancelledScreen(trip)
              : _buildTripScreen(trip);
        }

        // Cross-fade between stages instead of hard-cutting.
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          switchInCurve: Curves.easeOut,
          switchOutCurve: Curves.easeIn,
          child: KeyedSubtree(key: ValueKey(key), child: child),
        );
      },
    );
  }

  Widget _buildLoadingScreen() {
    return const Scaffold(
      backgroundColor: Color(0xFFF8FAF9),
      body: Center(
        child: CircularProgressIndicator(color: Color(0xFF16A34A)),
      ),
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