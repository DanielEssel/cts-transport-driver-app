// AUTH-04: driver sign-out goes offline and clears this device's push token
// before signing out, and always signs out even when cleanup fails.

import 'dart:async';

import 'package:cts_transport_driver_app/features/driver/services/driver_sign_out.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Fake {
  final calls = <String>[];
  String? uid = 'drv1';
  String? deviceToken = 'tok-this-device';
  String? profileToken = 'tok-this-device';
  bool signedIn = true;

  Future<void> Function() goOfflineImpl = () async {};
  Future<void> Function() deleteImpl = () async {};
  Future<void> Function() signOutImpl = () async {};

  DriverSignOut build({Duration timeout = const Duration(milliseconds: 50)}) =>
      DriverSignOut(
        currentUid: () => signedIn ? uid : null,
        goOffline: () {
          calls.add('offline(signedIn=$signedIn)');
          return goOfflineImpl();
        },
        readDeviceToken: () async => deviceToken,
        clearProfileTokenIfMatches: (u, t) async {
          calls.add('clearProfile($u, signedIn=$signedIn)');
          if (profileToken != t) return false;
          profileToken = null;
          return true;
        },
        deleteDeviceToken: () {
          calls.add('deleteDevice');
          return deleteImpl();
        },
        signOut: () {
          calls.add('signOut');
          return signOutImpl().then((_) => signedIn = false);
        },
        stepTimeout: timeout,
      );
}

void main() {
  test('goes offline and clears the token while signed in, then signs out', () async {
    final f = _Fake();
    final r = await f.build().run();

    expect(f.calls, [
      'offline(signedIn=true)',
      'clearProfile(drv1, signedIn=true)',
      'deleteDevice',
      'signOut',
    ]);
    expect(r.signedOut, isTrue);
    expect(f.profileToken, isNull);
  });

  test("another device's token on the profile is left alone", () async {
    final f = _Fake()..profileToken = 'tok-other-device';
    final r = await f.build().run();

    expect(f.profileToken, 'tok-other-device');
    expect(r.outcomes[SignOutStep.profileToken], StepOutcome.skipped);
    expect(r.signedOut, isTrue);
  });

  test('signs out even when every cleanup step fails', () async {
    final f = _Fake()
      ..goOfflineImpl = (() async => throw Exception('offline failed'))
      ..deleteImpl = (() async => throw Exception('fcm failed'));
    final r = await f.build().run();

    expect(r.outcomes[SignOutStep.offline], StepOutcome.failed);
    expect(r.outcomes[SignOutStep.deviceToken], StepOutcome.failed);
    expect(r.signedOut, isTrue);
  });

  test('signs out even when cleanup hangs (bounded by the timeout)', () async {
    final never = Completer<void>().future;
    final f = _Fake()
      ..goOfflineImpl = (() => never)
      ..deleteImpl = (() => never);
    final r = await f.build().run();

    expect(r.outcomes[SignOutStep.offline], StepOutcome.timedOut);
    expect(r.outcomes[SignOutStep.deviceToken], StepOutcome.timedOut);
    expect(r.signedOut, isTrue);
  });

  test('no signed-in user: skips profile cleanup, still signs out', () async {
    final f = _Fake()..signedIn = false;
    final r = await f.build().run();

    expect(f.calls, ['deleteDevice', 'signOut']);
    expect(r.outcomes[SignOutStep.offline], StepOutcome.skipped);
    expect(r.signedOut, isTrue);
  });

  test('a second sign-out after the first is a safe no-op on the profile', () async {
    final f = _Fake();
    await f.build().run();
    f.calls.clear();
    final r = await f.build().run();

    expect(f.calls, ['deleteDevice', 'signOut']);
    expect(r.signedOut, isTrue);
  });

  test('a failing auth sign-out is reported, not thrown', () async {
    final f = _Fake()..signOutImpl = (() async => throw Exception('auth'));
    final r = await f.build().run();

    expect(r.signedOut, isFalse);
    expect(r.outcomes[SignOutStep.auth], StepOutcome.failed);
  });

  test('the result text carries no uid or token', () async {
    final f = _Fake();
    final r = await f.build().run();

    expect(r.toString(), isNot(contains('drv1')));
    expect(r.toString(), isNot(contains('tok-')));
  });

  test('sign-out leaves SharedPreferences (onboarding flag) untouched', () async {
    SharedPreferences.setMockInitialValues({'onboarding_complete': true});
    final f = _Fake();
    await f.build().run();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('onboarding_complete'), isTrue);
  });
}
