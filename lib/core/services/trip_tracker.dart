import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';

import 'location/driver_location_publisher.dart';

export 'location/driver_location_publisher.dart' show trackerProblemFor;

/// Ride's view of the shared [DriverLocationPublisher]. Kept so the ride
/// screens keep their API; the publisher owns the only GPS stream, verifies
/// the trip is still this driver's before publishing, and stops itself when
/// the trip ends.
class TripTracker {
  TripTracker._(this._publisher);
  static final TripTracker instance =
      TripTracker._(DriverLocationPublisher.instance);

  final DriverLocationPublisher _publisher;

  ValueListenable<Position?> get position => _publisher.position;

  /// Why location sharing is not working for the current trip, or null while
  /// it is healthy (see DriverLocationPublisher.problem).
  ValueListenable<String?> get problem => _publisher.problem;

  bool get isRunning => _publisher.activeJob?.kind == ActiveJobKind.ride;

  /// Returns null on success, or a message the UI can show.
  Future<String?> start(String tripId) =>
      _publisher.startJob(ActiveJobKind.ride, tripId);

  /// Stops publishing, but only if this ride is what is running.
  Future<void> stop() async {
    if (isRunning) await _publisher.stopJob();
  }
}
