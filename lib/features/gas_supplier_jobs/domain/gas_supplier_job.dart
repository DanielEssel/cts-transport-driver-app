// Gas supplier jobs for drivers (functions/gas_supplier_fulfilment.js in
// the passenger repo). Drivers cannot read supplier orders directly: what a
// driver sees comes from the callables' answers.

double? _num(Object? v) => v is num ? v.toDouble() : null;

class GasSupplierPlace {
  final String? name, address;
  final double? latitude, longitude;
  const GasSupplierPlace({this.name, this.address, this.latitude, this.longitude});

  factory GasSupplierPlace.fromMap(Object? raw, {String? address}) {
    final m = raw is Map ? Map<String, dynamic>.from(raw) : const <String, dynamic>{};
    final loc = m['location'] is Map ? Map<String, dynamic>.from(m['location'] as Map) : m;
    return GasSupplierPlace(
      name: m['name'] as String?, address: (m['address'] as String?) ?? address,
      latitude: _num(loc['latitude']), longitude: _num(loc['longitude']),
    );
  }
}

class GasSupplierJob {
  final String orderId, orderType, cylinderSize;
  final int quantity;
  final GasSupplierPlace station, delivery;
  /// [distanceKm] is the server's straight-line distance from the driver to
  /// the customer (for choosing a job), never a road distance.
  final double? deliveryFee, distanceKm;
  /// The road route the order was quoted on, from the supplier's station
  /// (every leg), and its measured driving time; null when not returned.
  final double? routeDistanceKm;
  final int? routeDurationMinutes;
  /// The delivery estimate the customer was given (payment or acceptance
  /// time + the quoted ETA); null when the order has none.
  final int? estimatedDeliveryAtMs;
  /// The order's status, for the caller's own jobs (listMyGasSupplierJobs); null for open jobs.
  final String? status;
  /// For a linked-rider offer: its sequence (sent back on accept and decline)
  /// and when it lapses, in server time (see GasSupplierJobList.serverNowMs).
  final int? offerSeq, expiresAtMs;
  const GasSupplierJob({required this.orderId, required this.orderType, required this.cylinderSize, required this.quantity,
    required this.station, required this.delivery, this.deliveryFee, this.distanceKm, this.routeDistanceKm, this.routeDurationMinutes,
    this.estimatedDeliveryAtMs, this.status, this.offerSeq, this.expiresAtMs});

  factory GasSupplierJob.fromMap(Map<String, dynamic> m) {
    final riderFee = _num(m['deliveryFeePesewas']);
    return GasSupplierJob(
      orderId: '${m['orderId']}', orderType: '${m['orderType']}', cylinderSize: '${m['cylinderSize']}',
      quantity: (m['quantity'] as num?)?.toInt() ?? 1,
      station: GasSupplierPlace.fromMap(m['station']),
      delivery: GasSupplierPlace.fromMap({'location': m['deliveryLocation']}, address: m['deliveryAddress'] as String?),
      // An offer carries the fee CTSGo pays the rider, in pesewas, which the
      // server checks at accept: it wins over the order's delivery fee.
      deliveryFee: riderFee != null ? riderFee / 100 : _num(m['deliveryFee']),
      distanceKm: _num(m['distanceKm']),
      routeDistanceKm: _num(m['routeDistanceKm']),
      routeDurationMinutes: (m['routeDurationMinutes'] as num?)?.toInt(),
      estimatedDeliveryAtMs: (m['estimatedDeliveryAtMs'] as num?)?.toInt(),
      status: m['status'] as String?,
      offerSeq: (m['offerSeq'] as num?)?.toInt(), expiresAtMs: (m['expiresAtMs'] as num?)?.toInt(),
    );
  }
}

/// "6.2 km by road from the station · about 17 min driving", from the
/// server's quoted route only; null when the server returned no route.
String? gasRouteSummary(GasSupplierJob j) {
  final km = j.routeDistanceKm;
  if (km == null) return null;
  final mins = j.routeDurationMinutes;
  return '${km.toStringAsFixed(1)} km by road from the station${mins != null ? ' · about $mins min driving' : ''}';
}

/// What listGasSupplierJobs answers: open jobs, the caller's linked-rider
/// offers, and the server's clock (to correct the offer countdown).
class GasSupplierJobList {
  final List<GasSupplierJob> jobs, offers;
  final int? serverNowMs;
  const GasSupplierJobList({this.jobs = const [], this.offers = const [], this.serverNowMs});
}

/// One delivery fee the driver earned (listMyGasSupplierEarnings).
class GasSupplierEarning {
  final String orderId, status;
  final int amountPesewas;
  final int? deliveredAtMs, eligibleFromMs, creditedAtMs;
  final String? linkedSupplierName;
  const GasSupplierEarning({required this.orderId, required this.amountPesewas, required this.status,
    this.deliveredAtMs, this.eligibleFromMs, this.creditedAtMs, this.linkedSupplierName});

  factory GasSupplierEarning.fromMap(Map<String, dynamic> m) => GasSupplierEarning(
        orderId: '${m['orderId']}', amountPesewas: (m['amountPesewas'] as num?)?.toInt() ?? 0, status: '${m['status']}',
        deliveredAtMs: (m['deliveredAtMs'] as num?)?.toInt(), eligibleFromMs: (m['eligibleFromMs'] as num?)?.toInt(),
        creditedAtMs: (m['creditedAtMs'] as num?)?.toInt(), linkedSupplierName: m['linkedSupplierName'] as String?,
      );
}

/// Money stages never share a label: "earned" is the entitlement, "credited
/// to wallet" is in the CTSGo wallet; only a confirmed withdrawal is paid out,
/// which is not an earning status, so nothing here says "Paid".
String gasEarningLabel(String status) => switch (status) {
      'pending' => 'Earned · pending',
      'owed' => 'Owed',
      'credited_to_wallet' => 'Credited to wallet',
      'reversed' => 'Reversed',
      'outstanding_adjustment' => 'Under review',
      _ => 'Under review',
    };

const _labels = {
  'exchangeEmpty': 'Exchange cylinder', 'newCylinder': 'New cylinder', 'commercialBulk': 'Commercial bulk',
  'kg3': '3 kg', 'kg6': '6 kg', 'kg12_5': '12.5 kg', 'kg14_5': '14.5 kg', 'kg19': '19 kg', 'kg45': '45 kg',
};
String gasJobLabel(String v) => _labels[v] ?? v;

/// Where the driver is in a job, from the callables' answers.
enum GasSupplierJobStep { goingToStation, atStation, delivering, delivered }

/// Order statuses in which a supplier job is a driver's job in progress
/// (DRIVER_ACTIVE in functions/gas_supplier_fulfilment.js).
const gasSupplierDriverActive = {'driverAssigned', 'atStation', 'outForDelivery'};

/// Reasons a refused action may mean the job changed under the driver, so
/// the app asks the server where the job now stands.
const gasSupplierResyncReasons = {'network', 'order_not_found', 'released_from_job', 'invalid_transition'};

/// A reason for a failure the server gave no reason for.
String? gasSupplierTransportReason(String code) => switch (code) {
      'unavailable' || 'deadline-exceeded' || 'internal' || 'unknown' => 'network',
      'unauthenticated' => 'signed_out',
      'permission-denied' => 'not_allowed',
      _ => null,
    };

/// Where to resume one of the driver's own jobs, from its server status.
GasSupplierJobStep gasSupplierJobStep(String? status) => switch (status) {
      'atStation' => GasSupplierJobStep.atStation,
      'outForDelivery' => GasSupplierJobStep.delivering,
      'delivered' => GasSupplierJobStep.delivered,
      _ => GasSupplierJobStep.goingToStation,
    };

class GasSupplierJobFailure implements Exception {
  final String code;
  final String? reason;
  final String message;
  const GasSupplierJobFailure(this.code, this.reason, this.message);
  @override
  String toString() => 'GasSupplierJobFailure($code, $reason)';
}

/// What the driver is told for a refusal reason; the same wording as the
/// app's existing acceptance messages where the reason is shared.
String gasSupplierJobMessage(String? reason, String fallback) => switch (reason) {
      'gas_supplier_fulfilment_disabled' => 'Gas supplier jobs are not available yet.',
      'network' => "Couldn't reach CTSGo. Check your connection and try again.",
      'signed_out' => 'Your session has ended. Sign in again.',
      'not_allowed' => "You don't have access to this job.",
      'job_no_longer_yours' => 'This job is no longer in progress for you. It may have been completed, cancelled or reassigned.',
      'job_taken' => 'This job was just accepted by another driver.',
      'order_not_found' => 'This job is no longer available.',
      // An admin reassigned the job away from this driver (before hand-over).
      'released_from_job' => 'This job was reassigned to another driver.',
      'driver_not_found' => 'Your driver profile could not be found.',
      'driver_not_approved' => 'Your account is not approved to take jobs.',
      'driver_unavailable' => 'Go online to take jobs.',
      'driver_on_job' => 'Finish your current job first.',
      'wrong_service' => 'Gas jobs are for delivery drivers.',
      'vehicle_not_eligible' => 'Your vehicle cannot take this job.',
      'outside_radius' => 'This job is too far from you.',
      'station_location_invalid' => "This job's station is not available right now.",
      'offer_expired' => 'This offer has expired.',
      'offer_stale' || 'rider_fee_changed' => 'This offer changed. Pull to refresh.',
      'rider_not_linked' => "You're no longer linked to this supplier.",
      'driver_location_stale' => 'Your location is out of date. Turn on location and try again.',
      'driver_location_invalid' => 'Your location is not available. Turn on location and try again.',
      'invalid_transition' => 'The supplier has not handed over the cylinder yet. Ask them to confirm it in their portal.',
      'completion_code_mismatch' => 'That code is not right. Ask the customer to check it.',
      'completion_code_locked' => 'Too many wrong codes. Contact CTSGo support to finish this delivery.',
      'completion_code_pending' || 'completion_code_review' => 'This order needs CTSGo to confirm delivery. Contact support.',
      _ => fallback,
    };
