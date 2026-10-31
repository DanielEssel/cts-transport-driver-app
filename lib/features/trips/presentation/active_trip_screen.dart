// lib/features/trips/presentation/active_trip_screen.dart
//
// Trip in progress: drive to the drop-off, then complete.
// The shared RideJobScreen holds the map, live tracking and actions;
// TripFlowScreen shows this screen while the trip status matches.

import 'package:flutter/material.dart';

import '../models/trip_model.dart';
import 'ride_job_screen.dart';

class ActiveTripScreen extends StatelessWidget {
  final String tripId;
  final TripModel trip;

  const ActiveTripScreen({
    super.key,
    required this.tripId,
    required this.trip,
  });

  @override
  Widget build(BuildContext context) => RideJobScreen(
        tripId: tripId,
        trip: trip,
        stage: RideStage.onTrip,
      );
}
