// Reopening a trip: the driver's screen is chosen only from the stored
// status and assigned driver, so the app resumes exactly where the trip is.

import 'package:cts_transport_driver_app/features/trips/domain/ride_lifecycle.dart';
import 'package:cts_transport_driver_app/features/trips/models/trip_model.dart';
import 'package:flutter_test/flutter_test.dart';

DriverTripView viewFor(String? stored,
        {String? driverId = 'd1', String uid = 'd1'}) =>
    driverTripViewFor(
      status: TripStatus.fromFirestore(stored),
      tripDriverId: driverId,
      driverUid: uid,
    );

void main() {
  group('every status the apps or backend write resumes explicitly', () {
    const expected = {
      'tripAccepted': DriverTripView.toPickup,
      'driverArrived': DriverTripView.atPickup,
      'tripStarted': DriverTripView.onTrip,
      'completed': DriverTripView.completed,
      'cancelledByDriver': DriverTripView.cancelledByDriver,
      'cancelledByPassenger': DriverTripView.cancelledByPassenger,
      'noDriversAvailable': DriverTripView.closed,
      'expired': DriverTripView.closed,
      'cancelled': DriverTripView.closed,
      'flagged': DriverTripView.underReview,
      'searching': DriverTripView.notYours,
    };
    expected.forEach((stored, view) {
      test('"$stored" → ${view.name}', () => expect(viewFor(stored), view));
    });
  });

  test('progress is never reset: each stage reopens on itself', () {
    // Reading the same stored status twice gives the same stage.
    for (final s in ['tripAccepted', 'driverArrived', 'tripStarted']) {
      expect(viewFor(s), viewFor(s));
    }
    expect(viewFor('tripStarted'), isNot(DriverTripView.toPickup));
    expect(viewFor('driverArrived'), isNot(DriverTripView.toPickup));
  });

  test('unknown or missing statuses are not mistaken for a stage', () {
    expect(viewFor('inProgress'), DriverTripView.unknown);
    expect(viewFor('somethingNew'), DriverTripView.unknown);
    expect(viewFor(null), DriverTripView.unknown);
    expect(TripStatus.fromFirestore('somethingNew'), TripStatus.unknown);
  });

  test('an active trip assigned to someone else is not opened as yours', () {
    for (final s in ['tripAccepted', 'driverArrived', 'tripStarted']) {
      expect(viewFor(s, driverId: 'other'), DriverTripView.notYours);
      expect(viewFor(s, uid: ''), DriverTripView.notYours);
    }
  });

  test('stored values round-trip without inventing new ones', () {
    for (final s in TripStatus.values.where((s) => s != TripStatus.unknown)) {
      expect(TripStatus.fromFirestore(s.firestoreValue), s);
    }
  });
}
