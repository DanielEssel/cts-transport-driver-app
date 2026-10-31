// AUTH-08 / AUTH-09: automatic and manual verification share one path:
// sign in once, provision once (sign-up), and always route via the resolver.

import 'dart:async';

import 'package:cts_transport_driver_app/features/auth/domain/driver_auth_completion.dart';
import 'package:flutter_test/flutter_test.dart';

class _Fake {
  final calls = <String>[];
  Completer<void>? signInGate;
  Object? signInError;

  late final completion = DriverAuthCompletion<String, String>(
    signIn: (cred) async {
      calls.add('signIn($cred)');
      if (signInGate != null) await signInGate!.future;
      if (signInError != null) throw signInError!;
      return 'uid1';
    },
    provisionDriver: (phone) async => calls.add('provision'),
    resolve: (uid) async {
      calls.add('resolve($uid)');
      return 'route-for-$uid';
    },
  );
}

void main() {
  test('login: sign in then resolve, no provisioning', () async {
    final f = _Fake();
    final dest = await f.completion.complete('cred', isSignup: false, phone: 'p');

    expect(f.calls, ['signIn(cred)', 'resolve(uid1)']);
    expect(dest, 'route-for-uid1');
  });

  test('sign-up: sign in, provision, then resolve (not a hard-coded route)', () async {
    final f = _Fake();
    await f.completion.complete('cred', isSignup: true, phone: 'p');

    expect(f.calls, ['signIn(cred)', 'provision', 'resolve(uid1)']);
  });

  test('overlapping automatic + manual completion consume one credential', () async {
    final f = _Fake()..signInGate = Completer<void>();
    final auto = f.completion.complete('auto', isSignup: true, phone: 'p');
    final manual = f.completion.complete('manual', isSignup: true, phone: 'p');
    f.signInGate!.complete();

    expect(await auto, await manual);
    expect(f.calls, ['signIn(auto)', 'provision', 'resolve(uid1)']);
  });

  test('a failed sign-in does not provision or route, and a retry works', () async {
    final f = _Fake()..signInError = Exception('invalid code');
    await expectLater(
      f.completion.complete('bad', isSignup: true, phone: 'p'),
      throwsException,
    );
    expect(f.calls, ['signIn(bad)']);

    f.signInError = null;
    f.calls.clear();
    await f.completion.complete('good', isSignup: true, phone: 'p');
    expect(f.calls, ['signIn(good)', 'provision', 'resolve(uid1)']);
  });
}
