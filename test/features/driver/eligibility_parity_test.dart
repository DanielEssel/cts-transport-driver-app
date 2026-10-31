// The eligibility cases shared with the backend
// (functions/test/fixtures/eligibility_cases.json in the passenger repo,
// run there against dispatch_policy.js, which notification dispatch and the
// acceptance callables use). This copy must stay byte-identical; the
// backend test checks it. Here the request list's filter must give the same
// answer for every case.

import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart';
import 'package:cts_transport_driver_app/features/driver/presentation/widgets/dispatch_eligibility.dart';
import 'package:cts_transport_driver_app/features/driver/presentation/widgets/requests_section.dart';
import 'package:flutter_test/flutter_test.dart';

final _f = jsonDecode(
        File('test/fixtures/eligibility_cases.json').readAsStringSync())
    as Map<String, dynamic>;

GeoPoint _pt(List<dynamic> p) =>
    GeoPoint((p[0] as num).toDouble(), (p[1] as num).toDouble());

DriverProfile _driver(String id) {
  final spec = Map<String, dynamic>.from(_f['drivers'][id] as Map);
  final Object? loc = spec.containsKey('location')
      ? switch (spec['location']) {
          null => null,
          String key => _pt(_f[key] as List),
          List p => _pt(p),
          _ => null,
        }
      : _pt(_f['near'] as List);
  spec.remove('location');
  return DriverProfile.fromFirestore({
    'isApproved': true,
    'signupStep': 'approved',
    'isOnline': true,
    'isAvailable': true,
    ...spec,
    if (loc != null) 'location': loc,
  }, id);
}

AvailableRequest _request(Map<String, dynamic> job) {
  final at = _pt((job['point'] ?? _f['jobPoint']) as List);
  final service = job['service'] as String;
  return AvailableRequest(
    id: 'job',
    passengerId: 'p',
    type: switch (service) {
      'ride' => RequestType.ride,
      'delivery' => RequestType.delivery,
      _ => RequestType.gas,
    },
    status: 'open',
    pickupAddress: '',
    dropoffAddress: '',
    pickupLocation: at,
    dropoffLocation: service == 'gas' ? at : const GeoPoint(0, 0),
    fare: 0,
    createdAt: DateTime(2026),
    collection: 'x',
    serviceType: job['serviceType'] as String?,
    bookedVehicle: job['vehicleType'] as String?,
    weightTier: job['weightTier'] as String?,
    refillType: job['refillType'] as String?,
  );
}

void main() {
  for (final c in (_f['cases'] as List).cast<Map<String, dynamic>>()) {
    final job = Map<String, dynamic>.from(c['job'] as Map);
    final request = _request(job);
    test('ELG ${job.values.join(' ')}', () {
      if (c['jobRejection'] != null) {
        expect(jobRejection(request.dispatchJob), c['jobRejection']);
        for (final id in (_f['drivers'] as Map).keys.cast<String>()) {
          expect(eligibleRequests(_driver(id), [request]), isEmpty, reason: id);
        }
        return;
      }
      expect(jobRejection(request.dispatchJob), isNull);
      (c['expect'] as Map).forEach((id, want) {
        final d = _driver(id as String);
        expect(driverRejection(d, request.dispatchJob), want, reason: id);
        // The list shows exactly what the server would accept.
        expect(eligibleRequests(d, [request]).length, want == null ? 1 : 0,
            reason: '$id (list)');
      });
    });
  }
}
