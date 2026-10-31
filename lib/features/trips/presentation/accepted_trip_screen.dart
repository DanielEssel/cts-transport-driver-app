// lib/features/trips/presentation/accepted_trip_screen.dart
//
// Accepted ride: drive to the pickup, then mark arrival.
// The shared RideJobScreen holds the map, live tracking and actions;
// TripFlowScreen shows this screen while the trip status matches.

import 'package:flutter/material.dart';

import '../models/trip_model.dart';
import 'ride_job_screen.dart';

class AcceptedTripScreen extends StatelessWidget {
  final String tripId;
  final TripModel trip;

  const AcceptedTripScreen({
    super.key,
    required this.tripId,
    required this.trip,
  });

  @override
  Widget build(BuildContext context) => RideJobScreen(
        tripId: tripId,
        trip: trip,
        stage: RideStage.toPickup,
      );
}
