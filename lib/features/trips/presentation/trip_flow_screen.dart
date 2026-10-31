// lib/features/trips/presentation/trip_flow_screen.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cts_transport_driver_app/app/app_theme.dart';
import 'package:cts_transport_driver_app/core/services/marker_service.dart';

import '../../jobs/widgets/job_stage_panel.dart';

import '../domain/ride_lifecycle.dart';
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
          // The stage comes only from the stored status and assigned
          // driver, so reopening the app resumes exactly where the trip is.
          final view = driverTripViewFor(
            status: trip.status,
            tripDriverId: trip.driverId,
            driverUid: FirebaseAuth.instance.currentUser?.uid ?? '',
          );
          key = view;
          child = _buildTripScreen(trip, view);
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
      backgroundColor: AppTheme.background,
      body: Center(child: CircularProgressIndicator()),
    );
  }

  Widget _buildTripScreen(TripModel trip, DriverTripView view) {
    switch (view) {
      case DriverTripView.toPickup:
        return AcceptedTripScreen(tripId: widget.tripId, trip: trip);
      case DriverTripView.atPickup:
        return ArrivedTripScreen(tripId: widget.tripId, trip: trip);
      case DriverTripView.onTrip:
        return ActiveTripScreen(tripId: widget.tripId, trip: trip);
      case DriverTripView.completed:
        return TripCompletedScreen(tripId: widget.tripId, trip: trip);
      case DriverTripView.cancelledByDriver:
        return _buildEndedScreen(
          icon: Icons.cancel_rounded,
          color: AppTheme.warning,
          title: 'Trip Cancelled',
          message: 'You cancelled this trip.',
        );
      case DriverTripView.cancelledByPassenger:
        return _buildEndedScreen(
          icon: Icons.cancel_rounded,
          color: AppTheme.danger,
          title: 'Trip Cancelled',
          message: 'Passenger cancelled this trip.',
        );
      case DriverTripView.closed:
        return _buildEndedScreen(
          icon: Icons.event_busy_rounded,
          color: AppTheme.textSecondary,
          title: 'Request closed',
          message: 'This ride request ended before a trip took place.',
        );
      case DriverTripView.underReview:
        return _buildEndedScreen(
          icon: Icons.policy_rounded,
          color: AppTheme.warning,
          title: 'Trip under review',
          message: 'This trip is being reviewed by CTSGo support. '
              'No action is needed from you right now.',
        );
      case DriverTripView.notYours:
        return _buildEndedScreen(
          icon: Icons.person_off_rounded,
          color: AppTheme.textSecondary,
          title: 'Not your trip',
          message: 'This ride is not assigned to you.',
        );
      case DriverTripView.unknown:
        debugPrint('Trip ${widget.tripId}: unknown status "${trip.rawStatus}"');
        return _buildErrorScreen(
          'This trip has a status this app version does not recognise '
          '("${trip.rawStatus ?? 'none'}"). Please update the app or '
          'contact support.',
        );
    }
  }

  Widget _buildErrorScreen(String message) {
    return _buildEndedScreen(
      icon: Icons.error_outline_rounded,
      color: AppTheme.danger,
      title: 'Something went wrong',
      message: message,
    );
  }

  /// Same look as the delivery and gas ended screens; the one action
  /// still just goes back.
  Widget _buildEndedScreen({
    required IconData icon,
    required Color color,
    required String title,
    required String message,
  }) {
    return JobEndedScreen(
      icon: icon,
      color: color,
      title: title,
      message: message,
      doneLabel: 'Go Back',
      doneIcon: Icons.arrow_back_rounded,
      onDone: () => Navigator.pop(context),
    );
  }
}
