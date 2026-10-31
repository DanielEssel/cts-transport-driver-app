// lib/features/jobs/domain/job_stage_plan.dart
//
// What the driver sees and can do at each stage of a Ride, Delivery or Gas
// job, decided only from the job's stored status (the authoritative state).
//
// Every stage has exactly one status step (`from → to`), the same one the
// screens wrote before. A stage may also offer external navigation. While
// the driver is travelling, navigation is the primary action; once they are
// within [nearTargetMetres] of the target the status step takes over as
// primary. Opening or returning from navigation never changes the status.
//
// Pure, so it can be tested without Firestore or widgets.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../trips/domain/ride_lifecycle.dart';

/// Within this distance of the target, confirming arrival (or completion)
/// becomes the primary action and no "are you there?" check is needed.
const double nearTargetMetres = 200;

/// Where a stage's navigation goes.
enum JobTarget { pickup, dropoff, customer }

/// Extra check a status step needs before it is written.
enum JobGuard {
  /// Written straight away.
  none,

  /// Asks "Have you arrived?" when the driver is not near the target (or
  /// their position is unknown).
  arrival,

  /// Asks whether the passenger is on board (ride start).
  start,

  /// Ride completion: the existing "Complete trip?" confirmation.
  complete,

  /// Delivery / gas hand-over: the existing OTP check when the order has a
  /// code, otherwise a "Confirm delivery?" confirmation.
  handOver,
}

/// The single status step a stage offers.
class JobStep {
  final String from;
  final String to;
  final String label;
  final IconData icon;
  final JobGuard guard;

  /// Shown after the step succeeds (null when the screen changes anyway).
  final String? doneMessage;

  const JobStep({
    required this.from,
    required this.to,
    required this.label,
    required this.icon,
    this.guard = JobGuard.none,
    this.doneMessage,
  });
}

class JobStagePlan {
  /// Short names of the job's phases, shown as a progress indicator.
  final List<String> steps;
  final int stepIndex;

  /// Plain-language instruction for this stage.
  final String title;
  final String hint;

  final JobStep step;

  /// Navigation offered at this stage, if any.
  final JobTarget? target;
  final String? navigateLabel;

  /// True when navigation is the primary action (travelling and not yet
  /// near the target). The status step is then a secondary action.
  final bool navigatePrimary;

  const JobStagePlan({
    required this.steps,
    required this.stepIndex,
    required this.title,
    required this.hint,
    required this.step,
    this.target,
    this.navigateLabel,
    this.navigatePrimary = false,
  });

  /// Identifies the stage; changes whenever the stored status changes.
  String get key => step.from;
}

bool isNear(double? metres) => metres != null && metres <= nearTargetMetres;

/// Whether confirming arrival needs an "are you there?" check.
bool arrivalNeedsConfirm(double? metresToTarget) => !isNear(metresToTarget);

// ── Ride ────────────────────────────────────────────────────────────────────

const rideSteps = ['Go to pickup', 'Pick up', 'Drop off'];

JobStagePlan ridePlan(RideStep step, {double? metresToTarget}) {
  final near = isNear(metresToTarget);
  return switch (step) {
    RideStep.arrive => JobStagePlan(
        steps: rideSteps,
        stepIndex: 0,
        title: near ? "You're near the pickup" : 'Drive to the pickup',
        hint: near
            ? "Once you've stopped at the pickup, tap I've arrived. "
                'The passenger will be told you are there.'
            : 'Tap Navigate to pickup for directions in Google Maps. '
                "When you reach the pickup, tap I've arrived.",
        step: JobStep(
          from: step.from,
          to: step.to,
          label: "I've arrived",
          icon: Icons.place_rounded,
          guard: JobGuard.arrival,
          doneMessage: 'Arrival confirmed. The passenger has been told.',
        ),
        target: JobTarget.pickup,
        navigateLabel: 'Navigate to pickup',
        navigatePrimary: !near,
      ),
    RideStep.start => JobStagePlan(
        steps: rideSteps,
        stepIndex: 1,
        title: 'Wait for the passenger',
        hint: 'Start the trip only when the passenger is in your vehicle.',
        step: JobStep(
          from: step.from,
          to: step.to,
          label: 'Start trip',
          icon: Icons.play_arrow_rounded,
          guard: JobGuard.start,
          doneMessage: 'Trip started.',
        ),
      ),
    RideStep.complete => JobStagePlan(
        steps: rideSteps,
        stepIndex: 2,
        title: near ? "You're near the drop-off" : 'Drive to the drop-off',
        hint: near
            ? 'When the passenger has got out, tap Complete trip.'
            : 'Tap Navigate to drop-off for directions in Google Maps. '
                'At the drop-off, tap Complete trip.',
        step: JobStep(
          from: step.from,
          to: step.to,
          label: 'Complete trip',
          icon: Icons.flag_rounded,
          guard: JobGuard.complete,
        ),
        target: JobTarget.dropoff,
        navigateLabel: 'Navigate to drop-off',
        navigatePrimary: !near,
      ),
  };
}

// ── Delivery ────────────────────────────────────────────────────────────────

const deliverySteps = [
  'Go to pickup',
  'Collect',
  'Go to drop-off',
  'Hand over'
];

/// The plan for a delivery in [status], or null when the driver has nothing
/// to do (completed, cancelled, or a status this app does not know).
JobStagePlan? deliveryPlan(
  String status, {
  double? metresToTarget,
  bool hasOtp = false,
}) {
  final near = isNear(metresToTarget);
  JobStagePlan plan(int index, String title, String hint, JobStep step,
          {JobTarget? target, String? nav, bool travel = false}) =>
      JobStagePlan(
        steps: deliverySteps,
        stepIndex: index,
        title: title,
        hint: hint,
        step: step,
        target: target,
        navigateLabel: nav,
        navigatePrimary: travel && !near,
      );

  return switch (status) {
    'driverAssigned' => plan(
        0,
        'Head to the pickup',
        "Tap I'm on my way when you set off. "
            "The sender will be told you're coming.",
        const JobStep(
          from: 'driverAssigned',
          to: 'pickupEnroute',
          label: "I'm on my way",
          icon: Icons.directions_rounded,
          doneMessage: "The sender has been told you're on the way.",
        ),
        target: JobTarget.pickup,
        nav: 'Navigate to pickup',
      ),
    'pickupEnroute' => plan(
        0,
        near ? "You're near the pickup" : 'Drive to the pickup',
        near
            ? "Once you've stopped at the pickup, tap I've arrived at pickup."
            : 'Tap Navigate to pickup for directions in Google Maps. '
                "When you reach the pickup, tap I've arrived at pickup.",
        const JobStep(
          from: 'pickupEnroute',
          to: 'arrivedAtPickup',
          label: "I've arrived at pickup",
          icon: Icons.place_rounded,
          guard: JobGuard.arrival,
          doneMessage: 'Arrival confirmed. The sender has been told.',
        ),
        target: JobTarget.pickup,
        nav: 'Navigate to pickup',
        travel: true,
      ),
    'arrivedAtPickup' => plan(
        1,
        'Collect the parcel',
        'Check the parcel with the sender, then tap I have the parcel.',
        const JobStep(
          from: 'arrivedAtPickup',
          to: 'packagePicked',
          label: 'I have the parcel',
          icon: Icons.inventory_2_rounded,
          doneMessage: 'Parcel collected.',
        ),
      ),
    'packagePicked' => plan(
        2,
        'Head to the drop-off',
        "Tap I'm on my way when you set off. "
            "The receiver will be told you're coming.",
        const JobStep(
          from: 'packagePicked',
          to: 'deliveryEnroute',
          label: "I'm on my way",
          icon: Icons.local_shipping_rounded,
          doneMessage: "The receiver has been told you're on the way.",
        ),
        target: JobTarget.dropoff,
        nav: 'Navigate to drop-off',
      ),
    'deliveryEnroute' => plan(
        2,
        near ? "You're near the drop-off" : 'Drive to the drop-off',
        near
            ? "Once you've stopped at the drop-off, "
                "tap I've arrived at drop-off."
            : 'Tap Navigate to drop-off for directions in Google Maps. '
                "When you reach the drop-off, tap I've arrived at drop-off.",
        const JobStep(
          from: 'deliveryEnroute',
          to: 'arrivedAtDropoff',
          label: "I've arrived at drop-off",
          icon: Icons.place_rounded,
          guard: JobGuard.arrival,
          doneMessage: 'Arrival confirmed. The receiver has been told.',
        ),
        target: JobTarget.dropoff,
        nav: 'Navigate to drop-off',
        travel: true,
      ),
    'arrivedAtDropoff' => plan(
        3,
        'Hand over the parcel',
        hasOtp
            ? 'Give the parcel to the receiver and ask for their 4-digit '
                'code, then tap Confirm delivery.'
            : 'Give the parcel to the receiver, then tap Confirm delivery.',
        const JobStep(
          from: 'arrivedAtDropoff',
          to: 'completed',
          label: 'Confirm delivery',
          icon: Icons.check_circle_rounded,
          guard: JobGuard.handOver,
        ),
      ),
    _ => null,
  };
}

// ── Gas ─────────────────────────────────────────────────────────────────────

const gasDropOffSteps = ['Go to customer', 'Hand over'];
const gasRoundTripSteps = ['Go to customer', 'Collect', 'Refill', 'Return'];

/// The plan for a gas order in [status]. Mirrors the two existing flows:
/// `pickupAndReturn` (collect, refill, return) and a simple drop-off for
/// every other refill type. Null when the driver has nothing to do.
JobStagePlan? gasPlan(
  String status, {
  required String refillType,
  double? metresToTarget,
  bool hasOtp = false,
}) {
  final roundTrip = refillType == 'pickupAndReturn';
  final steps = roundTrip ? gasRoundTripSteps : gasDropOffSteps;
  final near = isNear(metresToTarget);
  JobStagePlan plan(int index, String title, String hint, JobStep step,
          {bool nav = false, bool travel = false}) =>
      JobStagePlan(
        steps: steps,
        stepIndex: index,
        title: title,
        hint: hint,
        step: step,
        target: nav ? JobTarget.customer : null,
        navigateLabel: nav ? 'Navigate to customer' : null,
        navigatePrimary: travel && !near,
      );
  final handOverHint = hasOtp
      ? "Give the gas to the customer and ask for their 4-digit code, "
          'then tap Confirm delivery.'
      : 'Give the gas to the customer, then tap Confirm delivery.';
  JobStep handOver(String from) => JobStep(
        from: from,
        to: 'delivered',
        label: 'Confirm delivery',
        icon: Icons.check_circle_rounded,
        guard: JobGuard.handOver,
      );

  return switch (status) {
    'driverAssigned' => plan(
        0,
        'Head to the customer',
        "Tap I'm on my way when you set off. "
            "The customer will be told you're coming.",
        const JobStep(
          from: 'driverAssigned',
          to: 'driverEnRoute',
          label: "I'm on my way",
          icon: Icons.directions_rounded,
          doneMessage: "The customer has been told you're on the way.",
        ),
        nav: true,
      ),
    'driverEnRoute' => plan(
        0,
        near ? "You're near the customer" : 'Drive to the customer',
        near
            ? "Once you've stopped at the customer, tap I've arrived."
            : 'Tap Navigate to customer for directions in Google Maps. '
                "When you get there, tap I've arrived.",
        const JobStep(
          from: 'driverEnRoute',
          to: 'driverArrived',
          label: "I've arrived",
          icon: Icons.place_rounded,
          guard: JobGuard.arrival,
          doneMessage: 'Arrival confirmed. The customer has been told.',
        ),
        nav: true,
        travel: true,
      ),
    'driverArrived' when !roundTrip =>
      plan(1, 'Hand over the gas', handOverHint, handOver('driverArrived')),
    'driverArrived' => plan(
        1,
        'Collect the empty cylinder',
        "Take the customer's cylinder, then tap I have the cylinder.",
        const JobStep(
          from: 'driverArrived',
          to: 'pickedUp',
          label: 'I have the cylinder',
          icon: Icons.propane_tank_rounded,
          doneMessage: 'Cylinder collected.',
        ),
      ),
    'pickedUp' when roundTrip => plan(
        2,
        'Take the cylinder to a refill station',
        "When you reach the station, tap I'm at the station.",
        const JobStep(
          from: 'pickedUp',
          to: 'atStation',
          label: "I'm at the station",
          icon: Icons.local_gas_station_rounded,
          doneMessage: 'The customer has been told you are at the station.',
        ),
      ),
    'atStation' when roundTrip => plan(
        2,
        'Refill the cylinder',
        'Tap Start refilling when the refill begins.',
        const JobStep(
          from: 'atStation',
          to: 'refilling',
          label: 'Start refilling',
          icon: Icons.local_fire_department_rounded,
          doneMessage: 'Refilling started.',
        ),
      ),
    'refilling' when roundTrip => plan(
        2,
        'Refilling',
        'When the cylinder is full, tap Refill finished and head back '
            'to the customer.',
        const JobStep(
          from: 'refilling',
          to: 'returning',
          label: 'Refill finished',
          icon: Icons.task_alt_rounded,
          doneMessage: "The customer has been told you're on the way back.",
        ),
      ),
    'returning' when roundTrip => plan(
        3,
        near ? "You're near the customer" : 'Return to the customer',
        near
            ? handOverHint
            : 'Tap Navigate to customer for directions in Google Maps. '
                'At the customer, hand over the gas and tap Confirm delivery.',
        handOver('returning'),
        nav: true,
        travel: true,
      ),
    _ => null,
  };
}

// ── Applying a delivery / gas step ──────────────────────────────────────────

/// Why a delivery or gas status step was refused, or null when it may
/// proceed. Same rule as rides: only the assigned driver, only from the
/// status the screen showed. A step that already happened is not refused
/// (idempotent), so a double tap or a retry never writes twice.
String? jobStepRefusal({
  required bool exists,
  required String? currentStatus,
  required String? jobDriverId,
  required String driverUid,
  required String from,
  required String to,
}) {
  if (!exists) return 'This job no longer exists.';
  if (driverUid.isEmpty || jobDriverId != driverUid) {
    return 'This job is no longer assigned to you.';
  }
  if (currentStatus == to) return null;
  if (currentStatus != from) {
    return 'This job has already moved on. Showing its latest status.';
  }
  return null;
}

class JobStepException implements Exception {
  final String message;
  const JobStepException(this.message);
  @override
  String toString() => message;
}

/// Writes the step `from → to` with [fields] (the same fields the screens
/// wrote before) in a transaction that re-reads the order first. Throws
/// [JobStepException] when refused; a step already applied is a no-op.
Future<void> applyJobStep(
  FirebaseFirestore db, {
  required String collection,
  required String docId,
  required String driverUid,
  required String from,
  required String to,
  required Map<String, dynamic> fields,
}) async {
  final ref = db.collection(collection).doc(docId);
  await db.runTransaction((tx) async {
    final snap = await tx.get(ref);
    final data = snap.data();
    final current = data?['status'] as String?;
    final refusal = jobStepRefusal(
      exists: snap.exists,
      currentStatus: current,
      jobDriverId: data?['driverId'] as String?,
      driverUid: driverUid,
      from: from,
      to: to,
    );
    if (refusal != null) throw JobStepException(refusal);
    if (current == to) return;
    tx.update(ref, {...fields, 'status': to});
  });
}
