// lib/features/trips/presentation/arrived_trip_screen.dart
//
// Driver at the pickup: start the trip once the passenger is in.
// The shared RideJobScreen holds the map, live tracking and actions;
// TripFlowScreen shows this screen while the trip status matches.

import 'package:flutter/material.dart';

import '../models/trip_model.dart';
import 'ride_job_screen.dart';

class ArrivedTripScreen extends StatelessWidget {
  final String tripId;
  final TripModel trip;

  const ArrivedTripScreen({
    super.key,
    required this.tripId,
    required this.trip,
  });

  @override
  Widget build(BuildContext context) => RideJobScreen(
        tripId: tripId,
        trip: trip,
        stage: RideStage.atPickup,
      );
}
