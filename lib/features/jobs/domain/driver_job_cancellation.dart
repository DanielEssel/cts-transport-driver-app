// lib/features/jobs/domain/driver_job_cancellation.dart
//
// Decides what a driver-initiated cancellation of a delivery or gas order may
// do, from data read inside the same Firestore transaction that applies it.
//
// Temporary client-side consistency fix (C4). It does not replace a
// server-enforced lifecycle: the server must eventually own cancellation and
// driver release.

enum DriverCancelOutcome {
  /// The order was active and assigned to this driver: cancel it.
  cancelled,

  /// The order was already cancelled (duplicate attempt or passenger
  /// cancelled first): nothing to cancel, only clear a stale busy state.
  alreadyCancelled,

  /// The order is missing or no longer assigned to this driver.
  notAssignedToDriver,

  /// The order is assigned to this driver but finished or in a state that
  /// cannot be cancelled (for example completed or delivered).
  notCancellable,
}

class DriverCancelDecision {
  const DriverCancelDecision({
    required this.outcome,
    required this.cancelOrder,
    required this.releaseDriver,
  });

  final DriverCancelOutcome outcome;

  /// Write the cancellation to the order.
  final bool cancelOrder;

  /// Set the driver available and clear `currentTripId`. Only ever true when
  /// the driver's own `currentTripId` still points at this order.
  final bool releaseDriver;
}

DriverCancelDecision decideDriverCancellation({
  required String driverUid,
  required String orderId,
  required bool orderExists,
  required Object? orderDriverId,
  required Object? orderStatus,
  required Set<String> cancellableStatuses,
  required String cancelledStatus,
  required Object? driverCurrentTripId,
}) {
  final ownsOrder = orderExists && orderDriverId is String && orderDriverId == driverUid;
  if (!ownsOrder) {
    return const DriverCancelDecision(
      outcome: DriverCancelOutcome.notAssignedToDriver,
      cancelOrder: false,
      releaseDriver: false,
    );
  }

  final busyWithThisOrder = driverCurrentTripId is String && driverCurrentTripId == orderId;

  if (orderStatus == cancelledStatus) {
    return DriverCancelDecision(
      outcome: DriverCancelOutcome.alreadyCancelled,
      cancelOrder: false,
      releaseDriver: busyWithThisOrder,
    );
  }

  if (orderStatus is! String || !cancellableStatuses.contains(orderStatus)) {
    return const DriverCancelDecision(
      outcome: DriverCancelOutcome.notCancellable,
      cancelOrder: false,
      releaseDriver: false,
    );
  }

  return DriverCancelDecision(
    outcome: DriverCancelOutcome.cancelled,
    cancelOrder: true,
    releaseDriver: busyWithThisOrder,
  );
}
