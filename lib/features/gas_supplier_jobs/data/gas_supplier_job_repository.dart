import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:cts_transport_driver_app/core/services/location/driver_location_publisher.dart';

import '../domain/gas_supplier_job.dart';

/// One callable invocation; Firebase in the app, a fake in tests.
typedef GasSupplierJobCall = Future<Map<String, dynamic>> Function(String name, Map<String, dynamic> data);

/// How long one callable may take before the driver is told to retry.
const gasSupplierCallTimeout = Duration(seconds: 20);

Future<Map<String, dynamic>> firebaseGasSupplierJobCall(String name, Map<String, dynamic> data) async {
  try {
    final r = await FirebaseFunctions.instanceFor(region: 'europe-west2').httpsCallable(name).call(data).timeout(gasSupplierCallTimeout);
    return r.data == null ? <String, dynamic>{} : Map<String, dynamic>.from(r.data as Map);
  } on FirebaseFunctionsException catch (e) {
    final details = e.details is Map ? Map<String, dynamic>.from(e.details as Map) : const <String, dynamic>{};
    final reason = (details['reason'] as String?) ?? gasSupplierTransportReason(e.code);
    throw GasSupplierJobFailure(e.code, reason, gasSupplierJobMessage(reason, e.message ?? 'Something went wrong. Please try again.'));
  } on TimeoutException {
    throw GasSupplierJobFailure('deadline-exceeded', 'network', gasSupplierJobMessage('network', ''));
  } catch (_) {
    // No connection, or any other client-side failure: never an unhandled error.
    throw GasSupplierJobFailure('unavailable', 'network', gasSupplierJobMessage('network', ''));
  }
}

/// The driver's side of a Gas supplier job. The server checks eligibility
/// (dispatch policy), assignment, hand-over and the customer's code.
/// A fresh fix written to the driver's profile, which the server reads when
/// it checks an offer; false when there is no fix (or nobody signed in).
Future<bool> refreshDriverLocation() async {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return false;
  final pos = await const GeolocatorLocationSource().currentPosition();
  if (pos == null) return false;
  await FirestoreJobLocationStore().writeProfileLocation(uid, pos);
  return true;
}

class GasSupplierJobRepository {
  final GasSupplierJobCall call;
  final Future<bool> Function() refreshLocation;
  GasSupplierJobRepository({GasSupplierJobCall? call, Future<bool> Function()? refreshLocation})
      : call = call ?? firebaseGasSupplierJobCall,
        refreshLocation = refreshLocation ?? refreshDriverLocation;

  /// Whether supplier jobs are switched on (settings/gas_supplier_fulfilment).
  /// Any failure, including the callable not being deployed, counts as off.
  Future<bool> available() async {
    try {
      final r = await call('gasSupplierOrderingStatus', const {}).timeout(const Duration(seconds: 8));
      return r['enabled'] == true;
    } catch (_) {
      return false;
    }
  }

  /// The driver's own jobs still in progress, so they can be resumed after
  /// leaving the screen or restarting the app (the server selects them by
  /// the caller's uid; the request carries nothing).
  ///
  /// Each order appears once, and only in a status the server lists as a
  /// driver's job in progress; this only narrows what the server returned.
  Future<List<GasSupplierJob>> myJobs() async {
    final r = await call('listMyGasSupplierJobs', const {});
    final seen = <String>{};
    final out = <GasSupplierJob>[];
    for (final raw in (r['jobs'] as List? ?? const [])) {
      if (raw is! Map) continue;
      final j = GasSupplierJob.fromMap(Map<String, dynamic>.from(raw));
      if (!gasSupplierDriverActive.contains(j.status) || !seen.add(j.orderId)) continue;
      out.add(j);
    }
    return out;
  }

  /// The driver's own job [orderId] as the server now sees it, or null when it
  /// is no longer theirs in progress (delivered, cancelled or reassigned).
  Future<GasSupplierJob?> myJob(String orderId) async {
    for (final j in await myJobs()) {
      if (j.orderId == orderId) return j;
    }
    return null;
  }

  /// Writes a fresh position if one is available; never fails. The server
  /// checks the CTSGo pool against the driver's profile position and its
  /// age, which idle tracking may have let go stale.
  Future<void> _refreshQuietly() async {
    try {
      await refreshLocation();
    } catch (_) {
      // The server decides on whatever position it has.
    }
  }

  Future<GasSupplierJobList> openJobs() async {
    await _refreshQuietly();
    final r = await call('listGasSupplierJobs', const {});
    List<GasSupplierJob> parse(Object? raw) =>
        [for (final j in (raw as List? ?? const [])) GasSupplierJob.fromMap(Map<String, dynamic>.from(j as Map))];
    return GasSupplierJobList(jobs: parse(r['jobs']), offers: parse(r['offers']), serverNowMs: (r['serverNowMs'] as num?)?.toInt());
  }

  /// Accepting an offer (with [offerSeq]) first writes a fresh position, so
  /// the server's distance check is not made on an old one; without a fix the
  /// server is not called. A CTSGo pool job refreshes the position when it
  /// can and is sent either way: the server's freshness check decides.
  Future<void> accept(String orderId, {int? offerSeq}) async {
    if (offerSeq == null) await _refreshQuietly();
    if (offerSeq != null) {
      bool fresh;
      try {
        fresh = await refreshLocation();
      } catch (_) {
        fresh = false;
      }
      if (!fresh) {
        throw GasSupplierJobFailure('failed-precondition', 'driver_location_stale', gasSupplierJobMessage('driver_location_stale', ''));
      }
    }
    await call('acceptGasSupplierJob', {'orderId': orderId, if (offerSeq != null) 'offerSeq': offerSeq});
  }

  Future<void> decline(String orderId, int offerSeq) =>
      call('declineGasSupplierRiderOffer', {'orderId': orderId, 'offerSeq': offerSeq});

  Future<List<GasSupplierEarning>> myEarnings() async {
    final r = await call('listMyGasSupplierEarnings', const {});
    return [for (final e in (r['earnings'] as List? ?? const [])) GasSupplierEarning.fromMap(Map<String, dynamic>.from(e as Map))];
  }

  Future<void> arrivedAtStation(String orderId) => call('arriveGasSupplierStation', {'orderId': orderId});

  /// Completes with the code the customer gives. Only digits are sent.
  Future<void> complete(String orderId, String code) {
    final digits = code.trim();
    if (!RegExp(r'^\d{3,8}$').hasMatch(digits)) {
      throw const GasSupplierJobFailure('invalid-argument', 'completion_code_mismatch', 'Enter the code the customer gives you.');
    }
    return call('completeGasSupplierOrder', {'orderId': orderId, 'code': digits});
  }
}
