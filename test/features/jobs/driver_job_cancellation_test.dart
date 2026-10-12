// C4-C: a driver cancelling a delivery or gas order frees themselves only
// when the cancellation is valid and they still own the assignment.

import 'package:cts_transport_driver_app/features/jobs/domain/driver_job_cancellation.dart';
import 'package:flutter_test/flutter_test.dart';

const _deliveryCancellable = {
  'driverAssigned',
  'pickupEnroute',
  'arrivedAtPickup',
  'packagePicked',
  'deliveryEnroute',
  'arrivedAtDropoff',
};
const _gasCancellable = {
  'driverAssigned',
  'driverEnRoute',
  'driverArrived',
  'pickedUp',
  'atStation',
  'refilling',
  'returning',
};

DriverCancelDecision _decide({
  String uid = 'drv1',
  String orderId = 'order1',
  bool exists = true,
  Object? orderDriverId = 'drv1',
  Object? status = 'pickupEnroute',
  Set<String> cancellable = _deliveryCancellable,
  Object? currentTripId = 'order1',
}) =>
    decideDriverCancellation(
      driverUid: uid,
      orderId: orderId,
      orderExists: exists,
      orderDriverId: orderDriverId,
      orderStatus: status,
      cancellableStatuses: cancellable,
      cancelledStatus: 'cancelled',
      driverCurrentTripId: currentTripId,
    );

void main() {
  group('successful cancellation', () {
    test('cancels and frees the driver at every cancellable delivery stage', () {
      for (final s in _deliveryCancellable) {
        final d = _decide(status: s);
        expect(d.outcome, DriverCancelOutcome.cancelled, reason: s);
        expect(d.cancelOrder, isTrue, reason: s);
        expect(d.releaseDriver, isTrue, reason: s);
      }
    });

    test('cancels and frees the driver at every cancellable gas stage', () {
      for (final s in _gasCancellable) {
        final d = _decide(status: s, cancellable: _gasCancellable);
        expect(d.cancelOrder && d.releaseDriver, isTrue, reason: s);
      }
    });

    test('cancels but does not touch the driver when they are busy with another job', () {
      final d = _decide(currentTripId: 'otherOrder');
      expect(d.cancelOrder, isTrue);
      expect(d.releaseDriver, isFalse);
    });

    test('cancels but does not release when the driver has no currentTripId', () {
      final d = _decide(currentTripId: null);
      expect(d.cancelOrder, isTrue);
      expect(d.releaseDriver, isFalse);
    });
  });

  group('assignment no longer matches', () {
    test('order reassigned to another driver: no cancel, no release', () {
      final d = _decide(orderDriverId: 'drv2');
      expect(d.outcome, DriverCancelOutcome.notAssignedToDriver);
      expect(d.cancelOrder, isFalse);
      expect(d.releaseDriver, isFalse);
    });

    test('order unassigned or missing: no cancel, no release (even if still marked busy)', () {
      for (final d in [_decide(orderDriverId: null), _decide(exists: false)]) {
        expect(d.outcome, DriverCancelOutcome.notAssignedToDriver);
        expect(d.cancelOrder || d.releaseDriver, isFalse);
      }
    });

    test('malformed driverId is treated as not assigned', () {
      final d = _decide(orderDriverId: 42);
      expect(d.cancelOrder || d.releaseDriver, isFalse);
    });
  });

  group('cancellation not possible (stale data)', () {
    test('a completed delivery or delivered gas order is not cancelled and the driver is not touched', () {
      for (final d in [
        _decide(status: 'completed'),
        _decide(status: 'delivered', cancellable: _gasCancellable),
      ]) {
        expect(d.outcome, DriverCancelOutcome.notCancellable);
        expect(d.cancelOrder || d.releaseDriver, isFalse);
      }
    });

    test('unknown or malformed status is not cancelled', () {
      for (final s in <Object?>['flagged', 'pendingOtp', null, 7]) {
        final d = _decide(status: s);
        expect(d.cancelOrder || d.releaseDriver, isFalse, reason: '$s');
      }
    });
  });

  group('duplicate cancellation', () {
    test('already cancelled: no second cancel write; stale busy state is cleared', () {
      final d = _decide(status: 'cancelled');
      expect(d.outcome, DriverCancelOutcome.alreadyCancelled);
      expect(d.cancelOrder, isFalse);
      expect(d.releaseDriver, isTrue);
    });

    test('already cancelled and driver already free: nothing to write', () {
      final d = _decide(status: 'cancelled', currentTripId: null);
      expect(d.cancelOrder || d.releaseDriver, isFalse);
    });

    test('already cancelled but driver moved on to another job: driver untouched', () {
      final d = _decide(status: 'cancelled', currentTripId: 'nextOrder');
      expect(d.releaseDriver, isFalse);
    });
  });
}
