// AUTH-05: a returning driver must not be routed off a cached profile that
// only holds the push-token write, and "no profile" must come from the server.

import 'package:cts_transport_driver_app/core/services/driver_profile_read.dart';
import 'package:flutter_test/flutter_test.dart';

DriverProfileStatus _c(Map<String, dynamic>? data, {required bool fromServer}) =>
    classifyDriverProfile(exists: data != null, data: data, fromServer: fromServer);

void main() {
  const driver = {'role': 'driver_hailing', 'isApproved': true};
  const tokenOnly = {'fcmToken': 't', 'platform': 'android'};

  test('server copy is usable', () {
    expect(_c(driver, fromServer: true), DriverProfileStatus.usable);
  });

  test('server copy without a role is still usable (new driver → role selection)', () {
    expect(_c(tokenOnly, fromServer: true), DriverProfileStatus.usable);
  });

  test('server says missing: not registered', () {
    expect(_c(null, fromServer: true), DriverProfileStatus.notRegistered);
  });

  test('cached copy with a role is usable offline', () {
    expect(_c(driver, fromServer: false), DriverProfileStatus.usable);
  });

  test('cached token-only copy is unverified, not routed to role selection', () {
    expect(_c(tokenOnly, fromServer: false), DriverProfileStatus.unverified);
  });

  test('cached missing copy is unverified, not "no account"', () {
    expect(_c(null, fromServer: false), DriverProfileStatus.unverified);
  });

  test('empty or non-string role in cache is unverified', () {
    expect(_c({'role': ''}, fromServer: false), DriverProfileStatus.unverified);
    expect(_c({'role': 3}, fromServer: false), DriverProfileStatus.unverified);
  });
}
