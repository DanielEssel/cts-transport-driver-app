// TripTracker must never look healthy when location sharing fails after
// start() returned (e.g. the foreground service being refused).

import 'package:cts_transport_driver_app/core/services/trip_tracker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';

void main() {
  test('a refused foreground service is reported, not ignored', () {
    // What Flutter's event channel delivers when startForeground() throws.
    final e = PlatformException(
      code: 'error',
      message: 'Permission Denial: startForeground from pid=1, uid=2 '
          'requires android.permission.FOREGROUND_SERVICE',
    );
    expect(trackerProblemFor(e), contains("Background location sharing"));
  });

  test('Android 14 missing location service type permission is reported', () {
    final e = PlatformException(
      code: 'error',
      message: 'Starting FGS with type location ... requires permissions: '
          'allOf=true [android.permission.FOREGROUND_SERVICE_LOCATION]',
    );
    expect(trackerProblemFor(e), contains("Background location sharing"));
  });

  test('revoked permission and disabled location get specific advice', () {
    expect(trackerProblemFor(const PermissionDeniedException('x')),
        contains('permission'));
    expect(trackerProblemFor(const LocationServiceDisabledException()),
        contains('Location is turned off'));
  });

  test('any other stream error still surfaces a problem', () {
    expect(trackerProblemFor(StateError('boom')), isNotEmpty);
  });

  test('the tracker starts with no problem reported', () {
    expect(TripTracker.instance.problem.value, isNull);
  });
}
