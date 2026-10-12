// AUTH-03: signing in must not create a driver profile, and provisioning
// must never overwrite or self-grant protected fields.

import 'package:cts_transport_driver_app/core/services/driver_profile_defaults.dart';
import 'package:cts_transport_driver_app/features/driver/services/push_token_store.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('token save', () {
    test('writes only token fields via update', () async {
      Map<String, Object?>? written;
      final saved = await saveTokenToExistingProfile(
        update: (f) async => written = f,
        token: 't',
        platform: 'android',
        serverTimestamp: 'ts',
      );
      expect(saved, isTrue);
      expect(written!.keys.toSet(), {'fcmToken', 'fcmTokenUpdatedAt', 'platform'});
    });

    test('no profile yet: skipped, nothing created', () async {
      final saved = await saveTokenToExistingProfile(
        update: (_) async =>
            throw FirebaseException(plugin: 'cloud_firestore', code: 'not-found'),
        token: 't',
        platform: 'android',
        serverTimestamp: 'ts',
      );
      expect(saved, isFalse);
    });

    test('other errors are surfaced, not swallowed as "no profile"', () async {
      expect(
        saveTokenToExistingProfile(
          update: (_) async => throw FirebaseException(
              plugin: 'cloud_firestore', code: 'permission-denied'),
          token: 't',
          platform: 'android',
          serverTimestamp: 'ts',
        ),
        throwsA(isA<FirebaseException>()),
      );
    });
  });

  group('provisioning an existing doc', () {
    test('token-only doc gets onboarding defaults, never protected fields', () {
      final add = missingOwnerDefaults(
          {'fcmToken': 't', 'platform': 'android'}, 'uid1', '+233000000000');
      expect(add['accountSetupComplete'], isFalse);
      expect(add['serviceType'], 'taxi');
      expect(add.containsKey('isApproved'), isFalse);
      expect(add.containsKey('uid'), isFalse);
      expect(add.containsKey('createdAt'), isFalse);
      expect(add.containsKey('fcmToken'), isFalse);
    });

    test('existing values are never overwritten', () {
      final add = missingOwnerDefaults({
        'role': 'driver_hailing',
        'serviceType': 'okada',
        'accountSetupComplete': true,
      }, 'uid1', '+233000000000');
      expect(add.containsKey('role'), isFalse);
      expect(add.containsKey('serviceType'), isFalse);
      expect(add.containsKey('accountSetupComplete'), isFalse);
    });

    test('a new profile starts unapproved and offline', () {
      final d = newDriverDefaults('uid1', '+233000000000');
      expect(d['isApproved'], isFalse);
      expect(d['isOnline'], isFalse);
      expect(d['isAvailable'], isFalse);
    });
  });
}
