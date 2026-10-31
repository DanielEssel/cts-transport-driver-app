// What the driver can do at each stage of a Ride, Delivery or Gas job.
// The plans must offer exactly the status step the screens wrote before
// (no new states, no skipped stages), and nothing for ended jobs.

import 'package:cts_transport_driver_app/features/jobs/domain/job_stage_plan.dart';
import 'package:cts_transport_driver_app/features/trips/domain/ride_lifecycle.dart';
import 'package:flutter_test/flutter_test.dart';

/// The status progression the Delivery screen used before the redesign.
const _legacyDelivery = {
  'driverAssigned': 'pickupEnroute',
  'pickupEnroute': 'arrivedAtPickup',
  'arrivedAtPickup': 'packagePicked',
  'packagePicked': 'deliveryEnroute',
  'deliveryEnroute': 'arrivedAtDropoff',
  'arrivedAtDropoff': 'completed',
};

/// The Gas screen's two flows before the redesign.
const _legacyGasDropOff = {
  'driverAssigned': 'driverEnRoute',
  'driverEnRoute': 'driverArrived',
  'driverArrived': 'delivered',
};
const _legacyGasRoundTrip = {
  'driverAssigned': 'driverEnRoute',
  'driverEnRoute': 'driverArrived',
  'driverArrived': 'pickedUp',
  'pickedUp': 'atStation',
  'atStation': 'refilling',
  'refilling': 'returning',
  'returning': 'delivered',
};

void main() {
  group('ride', () {
    test('each stage offers only its own lifecycle step', () {
      for (final step in RideStep.values) {
        final plan = ridePlan(step);
        expect(plan.step.from, step.from, reason: step.name);
        expect(plan.step.to, step.to, reason: step.name);
      }
    });

    test('heading to the pickup: navigation leads, arrival is secondary', () {
      final far = ridePlan(RideStep.arrive, metresToTarget: 2400);
      expect(far.navigateLabel, 'Navigate to pickup');
      expect(far.navigatePrimary, isTrue);
      expect(far.step.label, "I've arrived");
      expect(far.step.guard, JobGuard.arrival);
    });

    test('no GPS fix yet: navigation still leads', () {
      expect(ridePlan(RideStep.arrive).navigatePrimary, isTrue);
    });

    test('near the pickup: arrival becomes the primary action', () {
      final near = ridePlan(RideStep.arrive, metresToTarget: 80);
      expect(near.navigatePrimary, isFalse);
      expect(near.step.to, 'driverArrived');
    });

    test('waiting at the pickup: Start trip only, with a check', () {
      final plan = ridePlan(RideStep.start, metresToTarget: 5);
      expect(plan.navigateLabel, isNull);
      expect(plan.target, isNull);
      expect(plan.step.label, 'Start trip');
      expect(plan.step.guard, JobGuard.start);
    });

    test('on trip: navigate to drop-off, then Complete trip (confirmed)', () {
      final far = ridePlan(RideStep.complete, metresToTarget: 5000);
      expect(far.navigateLabel, 'Navigate to drop-off');
      expect(far.navigatePrimary, isTrue);
      expect(far.step.guard, JobGuard.complete);
      expect(ridePlan(RideStep.complete, metresToTarget: 50).navigatePrimary,
          isFalse);
    });

    test('progress follows the stored stage', () {
      expect(RideStep.values.map((s) => ridePlan(s).stepIndex), [0, 1, 2]);
    });
  });

  group('delivery', () {
    test('every stage writes the same next status as before', () {
      _legacyDelivery.forEach((from, to) {
        final plan = deliveryPlan(from)!;
        expect(plan.step.from, from);
        expect(plan.step.to, to, reason: from);
      });
    });

    test('ended or unknown deliveries offer no action', () {
      for (final s in [
        'completed',
        'cancelled',
        'cancelledByDriver',
        'cancelledByPassenger',
        'pending',
        'somethingNew',
        '',
      ]) {
        expect(deliveryPlan(s), isNull, reason: s);
      }
    });

    test('arrivals are guarded, hand-over keeps the OTP / confirm check', () {
      expect(deliveryPlan('pickupEnroute')!.step.guard, JobGuard.arrival);
      expect(deliveryPlan('deliveryEnroute')!.step.guard, JobGuard.arrival);
      expect(deliveryPlan('arrivedAtDropoff')!.step.guard, JobGuard.handOver);
      expect(deliveryPlan('arrivedAtPickup')!.step.guard, JobGuard.none);
    });

    test('navigation leads only while travelling and not yet near', () {
      expect(
          deliveryPlan('pickupEnroute', metresToTarget: 900)!.navigatePrimary,
          isTrue);
      expect(
          deliveryPlan('pickupEnroute', metresToTarget: 100)!.navigatePrimary,
          isFalse);
      // Setting off: "I'm on my way" leads; navigation is offered too.
      final setOff = deliveryPlan('driverAssigned', metresToTarget: 900)!;
      expect(setOff.navigatePrimary, isFalse);
      expect(setOff.target, JobTarget.pickup);
      // At the pickup / drop-off: nothing to navigate to.
      expect(deliveryPlan('arrivedAtPickup')!.target, isNull);
      expect(deliveryPlan('arrivedAtDropoff')!.target, isNull);
      expect(deliveryPlan('deliveryEnroute')!.target, JobTarget.dropoff);
    });

    test('hand-over wording asks for the code only when there is one', () {
      expect(deliveryPlan('arrivedAtDropoff', hasOtp: true)!.hint,
          contains('4-digit code'));
      expect(deliveryPlan('arrivedAtDropoff')!.hint, isNot(contains('code')));
    });
  });

  group('gas', () {
    test('drop-off flow writes the same next status as before', () {
      _legacyGasDropOff.forEach((from, to) {
        final plan = gasPlan(from, refillType: 'exchange')!;
        expect(plan.step.to, to, reason: from);
      });
      expect(gasPlan('driverArrived', refillType: '')!.step.guard,
          JobGuard.handOver);
    });

    test('round-trip flow writes the same next status as before', () {
      _legacyGasRoundTrip.forEach((from, to) {
        final plan = gasPlan(from, refillType: 'pickupAndReturn')!;
        expect(plan.step.to, to, reason: from);
      });
      expect(gasPlan('returning', refillType: 'pickupAndReturn')!.step.guard,
          JobGuard.handOver);
    });

    test('ended orders and statuses outside the flow offer no action', () {
      for (final s in ['delivered', 'cancelled', 'failed', 'pendingApproval']) {
        expect(gasPlan(s, refillType: 'pickupAndReturn'), isNull, reason: s);
        expect(gasPlan(s, refillType: 'exchange'), isNull, reason: s);
      }
      // A round-trip status on a drop-off order used to fall through to
      // "Mark as Delivered"; now it offers nothing.
      for (final s in ['pickedUp', 'atStation', 'refilling', 'returning']) {
        expect(gasPlan(s, refillType: 'exchange'), isNull, reason: s);
      }
    });

    test('navigation goes to the customer, never on the station leg', () {
      for (final s in ['pickedUp', 'atStation', 'refilling']) {
        expect(gasPlan(s, refillType: 'pickupAndReturn')!.target, isNull,
            reason: s);
      }
      expect(gasPlan('driverEnRoute', refillType: 'x')!.target,
          JobTarget.customer);
      expect(gasPlan('returning', refillType: 'pickupAndReturn')!.target,
          JobTarget.customer);
    });
  });

  group('arrival check', () {
    test('asked when far away or when the position is unknown', () {
      expect(arrivalNeedsConfirm(null), isTrue);
      expect(arrivalNeedsConfirm(nearTargetMetres + 1), isTrue);
      expect(arrivalNeedsConfirm(nearTargetMetres), isFalse);
      expect(arrivalNeedsConfirm(30), isFalse);
    });
  });

  group('jobStepRefusal', () {
    String? refusal(String? status,
            {bool exists = true, String? driverId = 'd1', String uid = 'd1'}) =>
        jobStepRefusal(
          exists: exists,
          currentStatus: status,
          jobDriverId: driverId,
          driverUid: uid,
          from: 'arrivedAtDropoff',
          to: 'completed',
        );

    test('proceeds only from the status the screen showed', () {
      expect(refusal('arrivedAtDropoff'), isNull);
      expect(refusal('deliveryEnroute'), isNotNull); // cannot skip arrival
      expect(refusal('pickupEnroute'), isNotNull);
    });

    test('never overwrites a cancelled job', () {
      for (final s in [
        'cancelled',
        'cancelledByDriver',
        'cancelledByPassenger'
      ]) {
        expect(refusal(s), isNotNull, reason: s);
      }
    });

    test('a repeated step is accepted without a second write', () {
      // applyJobStep returns early when the status is already `to`.
      expect(refusal('completed'), isNull);
    });

    test('only the assigned driver, and only an existing job', () {
      expect(refusal('arrivedAtDropoff', driverId: 'other'), isNotNull);
      expect(refusal('arrivedAtDropoff', uid: ''), isNotNull);
      expect(refusal('arrivedAtDropoff', exists: false), isNotNull);
    });
  });
}
