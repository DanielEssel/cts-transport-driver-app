// lib/features/trips/domain/ride_lifecycle.dart
//
// The driver's ride steps, in order, using the existing trip statuses:
//
//   tripAccepted ──arrive──▶ driverArrived ──start──▶ tripStarted
//                                                        │
//                                              complete ─▼
//                                                     completed
//
// Each step is applied in a Firestore transaction that re-reads the trip and
// only proceeds from the expected current status, for the assigned driver.
// That blocks skipping a step (e.g. completing a ride that never started)
// from stale screens, double taps and restored app state. It is a client
// check only: Firestore rules do not yet enforce the order (see the separate
// backend proposal).

import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/trip_model.dart';

enum RideStep {
  arrive('tripAccepted', 'driverArrived', null),
  start('driverArrived', 'tripStarted', 'startedAt'),
  complete('tripStarted', 'completed', 'completedAt');

  /// Status the trip must be in for this step.
  final String from;

  /// Status the step writes.
  final String to;

  /// Existing timestamp field written with the step, if any.
  final String? timestampField;

  const RideStep(this.from, this.to, this.timestampField);
}

/// Why a step was refused, or null when it may proceed.
///
/// Pure, so it can be tested without Firestore.
String? rideStepRefusal({
  required RideStep step,
  required bool tripExists,
  required String? currentStatus,
  required String? tripDriverId,
  required String driverUid,
}) {
  if (!tripExists) return 'This trip no longer exists.';
  if (driverUid.isEmpty || tripDriverId != driverUid) {
    return 'This trip is not assigned to you.';
  }
  if (currentStatus == step.to) return null; // already done: idempotent
  if (currentStatus != step.from) {
    return switch (currentStatus) {
      'cancelledByPassenger' => 'The passenger cancelled this trip.',
      'cancelledByDriver' => 'This trip was cancelled.',
      'completed' => 'This trip is already completed.',
      _ => switch (step) {
          RideStep.arrive =>
            'You can only mark arrival before the trip starts.',
          RideStep.start =>
            'Mark that you have arrived before starting the trip.',
          RideStep.complete => 'Start the trip before completing it.',
        },
    };
  }
  return null;
}

class RideStepException implements Exception {
  final String message;
  const RideStepException(this.message);
  @override
  String toString() => message;
}

/// Applies [step] to the trip, or throws [RideStepException] with a message
/// the driver can act on. Repeating a step that already happened is a no-op.
Future<void> applyRideStep(
  FirebaseFirestore db, {
  required String tripId,
  required String driverUid,
  required RideStep step,
}) async {
  final ref = db.collection('trips').doc(tripId);
  await db.runTransaction((tx) async {
    final snap = await tx.get(ref);
    final data = snap.data();
    final current = data?['status'] as String?;
    final refusal = rideStepRefusal(
      step: step,
      tripExists: snap.exists,
      currentStatus: current,
      tripDriverId: data?['driverId'] as String?,
      driverUid: driverUid,
    );
    if (refusal != null) throw RideStepException(refusal);
    if (current == step.to) return; // already applied
    tx.update(ref, {
      'status': step.to,
      if (step.timestampField != null)
        step.timestampField!: FieldValue.serverTimestamp(),
    });
  });
}

/// What the driver's trip screen shows for a trip, decided only from the
/// trip's stored status and assigned driver (the authoritative state). Used
/// on every open and reopen, so the screen always matches real progress and
/// never moves a trip backwards or forwards on its own.
enum DriverTripView {
  toPickup,
  atPickup,
  onTrip,
  completed,
  cancelledByDriver,
  cancelledByPassenger,

  /// The request ended without a ride (no driver found, expired, legacy
  /// `cancelled`).
  closed,

  /// Held by the backend for review (`flagged`).
  underReview,

  /// Still searching, or assigned to a different driver.
  notYours,

  /// A status this app version doesn't know.
  unknown,
}

DriverTripView driverTripViewFor({
  required TripStatus status,
  required String? tripDriverId,
  required String driverUid,
}) {
  final assignedToMe = driverUid.isNotEmpty && tripDriverId == driverUid;
  return switch (status) {
    TripStatus.searching => DriverTripView.notYours,
    TripStatus.tripAccepted ||
    TripStatus.driverArrived ||
    TripStatus.tripStarted when !assignedToMe =>
      DriverTripView.notYours,
    TripStatus.tripAccepted => DriverTripView.toPickup,
    TripStatus.driverArrived => DriverTripView.atPickup,
    TripStatus.tripStarted => DriverTripView.onTrip,
    TripStatus.completed => DriverTripView.completed,
    TripStatus.cancelledByDriver => DriverTripView.cancelledByDriver,
    TripStatus.cancelledByPassenger => DriverTripView.cancelledByPassenger,
    TripStatus.noDriversAvailable ||
    TripStatus.expired ||
    TripStatus.cancelled =>
      DriverTripView.closed,
    TripStatus.flagged => DriverTripView.underReview,
    TripStatus.unknown => DriverTripView.unknown,
  };
}
