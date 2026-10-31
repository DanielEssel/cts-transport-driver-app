// Ride lifecycle: accepted → arrived → started → completed, in order, for
// the assigned driver only. Completion is never allowed before the start.

import 'package:cts_transport_driver_app/features/jobs/domain/driver_job_cancellation.dart';
import 'package:cts_transport_driver_app/features/trips/domain/ride_lifecycle.dart';
import 'package:cts_transport_driver_app/features/trips/models/trip_model.dart';
import 'package:cts_transport_driver_app/features/trips/presentation/ride_job_screen.dart';
import 'package:flutter_test/flutter_test.dart';

String? refusal(RideStep step, String? status,
        {bool exists = true, String? driverId = 'd1', String uid = 'd1'}) =>
    rideStepRefusal(
      step: step,
      tripExists: exists,
      currentStatus: status,
      tripDriverId: driverId,
      driverUid: uid,
    );

void main() {
  group('step order', () {
    test('each step proceeds only from its own status', () {
      expect(refusal(RideStep.arrive, 'tripAccepted'), isNull);
      expect(refusal(RideStep.start, 'driverArrived'), isNull);
      expect(refusal(RideStep.complete, 'tripStarted'), isNull);
    });

    test('a ride can never be completed before it started', () {
      for (final s in ['tripAccepted', 'driverArrived', 'searching', null]) {
        expect(refusal(RideStep.complete, s), isNotNull, reason: '$s');
      }
    });

    test('a trip cannot start before the driver arrived', () {
      expect(refusal(RideStep.start, 'tripAccepted'), isNotNull);
    });

    test('arrival cannot be marked once the trip started', () {
      expect(refusal(RideStep.arrive, 'tripStarted'), isNotNull);
    });

    test('repeating a step that already happened is a no-op, not an error', () {
      expect(refusal(RideStep.arrive, 'driverArrived'), isNull);
      expect(refusal(RideStep.start, 'tripStarted'), isNull);
      expect(refusal(RideStep.complete, 'completed'), isNull);
    });

    test('cancelled trips explain why', () {
      expect(refusal(RideStep.start, 'cancelledByPassenger'),
          'The passenger cancelled this trip.');
      expect(refusal(RideStep.complete, 'cancelledByDriver'),
          'This trip was cancelled.');
    });
  });

  group('authority', () {
    test('only the assigned driver may advance the trip', () {
      expect(refusal(RideStep.arrive, 'tripAccepted', driverId: 'other'),
          'This trip is not assigned to you.');
      expect(refusal(RideStep.arrive, 'tripAccepted', uid: ''), isNotNull);
    });

    test('a missing trip is refused', () {
      expect(refusal(RideStep.arrive, null, exists: false), isNotNull);
    });
  });

  group('screen stages', () {
    test('stages follow the trip statuses in order', () {
      expect(RideStage.toPickup.status, TripStatus.tripAccepted);
      expect(RideStage.atPickup.status, TripStatus.driverArrived);
      expect(RideStage.onTrip.status, TripStatus.tripStarted);
      // Each stage's action moves the trip to the next stage's status.
      expect(
          RideStage.toPickup.step.to, RideStage.atPickup.status.firestoreValue);
      expect(
          RideStage.atPickup.step.to, RideStage.onTrip.status.firestoreValue);
      expect(RideStage.onTrip.step.to, TripStatus.completed.firestoreValue);
    });

    test('after accepting, the driver is sent to the pickup, not the drop-off',
        () {
      expect(RideStage.toPickup.navigateLabel, 'Navigate to pickup');
      expect(RideStage.toPickup.headsToPickup, isTrue);
      expect(RideStage.toPickup.step, isNot(RideStep.complete));
    });

    test('only the started trip offers completion and drop-off navigation', () {
      for (final stage in RideStage.values) {
        final completes = stage.step == RideStep.complete;
        expect(completes, stage == RideStage.onTrip, reason: stage.name);
        expect(stage.navigateLabel == 'Navigate to drop-off',
            stage == RideStage.onTrip,
            reason: stage.name);
      }
    });

    test('waiting at the pickup has no navigation, only Start trip', () {
      expect(RideStage.atPickup.navigateLabel, isNull);
      expect(RideStage.atPickup.actionLabel, 'Start trip');
    });
  });

  group('ride cancel (driver)', () {
    test('cancels an active trip assigned to the driver', () {
      for (final s in ['tripAccepted', 'driverArrived', 'tripStarted']) {
        final d = rideCancel(s);
        expect(d.cancelOrder, isTrue, reason: s);
        expect(d.releaseDriver, isTrue, reason: s);
      }
    });

    test('never overwrites a trip that already ended', () {
      for (final s in ['completed', 'cancelledByPassenger', 'expired']) {
        final d = rideCancel(s);
        expect(d.cancelOrder, isFalse, reason: s);
        expect(d.outcome, DriverCancelOutcome.notCancellable, reason: s);
      }
    });

    test("cannot cancel someone else's trip", () {
      expect(rideCancel('tripStarted', driverId: 'other').cancelOrder, isFalse);
    });
  });
}

// Ride cancel uses the shared job-cancellation rule with the unchanged
// policy (cancellable before completion), read inside the transaction.
DriverCancelDecision rideCancel(String status, {String? driverId = 'd1'}) =>
    decideDriverCancellation(
      driverUid: 'd1',
      orderId: 't1',
      orderExists: true,
      orderDriverId: driverId,
      orderStatus: status,
      cancellableStatuses: const {
        'tripAccepted',
        'driverArrived',
        'tripStarted'
      },
      cancelledStatus: 'cancelledByDriver',
      driverCurrentTripId: 't1',
    );
