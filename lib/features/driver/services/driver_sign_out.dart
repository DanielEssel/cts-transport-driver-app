// lib/features/driver/services/driver_sign_out.dart
//
// The one driver sign-out sequence (AUTH-04). Every logout entry point goes
// through DriverSessionService.signOut(), which runs this.
//
// Order matters:
//   1. capture the uid           (before anything can sign the user out)
//   2. go offline                (stop dispatch + the passenger map marker)
//   3. clear THIS device's token  (only if drivers/{uid}.fcmToken still
//                                  matches, so another device keeps its pushes)
//   4. delete the local FCM token
//   5. Firebase sign-out          (always attempted, whatever failed above)
//
// Steps 2–4 are bounded and never throw, so a slow or failing network cannot
// leave the driver unable to sign out. Nothing here touches SharedPreferences.

import 'dart:async';

enum SignOutStep { offline, profileToken, deviceToken, auth }

enum StepOutcome { done, skipped, failed, timedOut }

class DriverSignOutResult {
  const DriverSignOutResult(this.outcomes);

  final Map<SignOutStep, StepOutcome> outcomes;

  bool get signedOut => outcomes[SignOutStep.auth] == StepOutcome.done;

  /// Step names and outcomes only — safe to log (no uid, no token).
  @override
  String toString() => outcomes.entries
      .map((e) => '${e.key.name}=${e.value.name}')
      .join(', ');
}

class DriverSignOut {
  DriverSignOut({
    required this.currentUid,
    required this.goOffline,
    required this.readDeviceToken,
    required this.clearProfileTokenIfMatches,
    required this.deleteDeviceToken,
    required this.signOut,
    this.stepTimeout = const Duration(seconds: 5),
  });

  final String? Function() currentUid;
  final Future<void> Function() goOffline;
  final Future<String?> Function() readDeviceToken;

  /// Removes fcmToken from the driver's profile only if it equals [token].
  /// Returns false when nothing was removed (no profile, or a different
  /// device's token). Must not create a profile.
  final Future<bool> Function(String uid, String token)
      clearProfileTokenIfMatches;
  final Future<void> Function() deleteDeviceToken;
  final Future<void> Function() signOut;
  final Duration stepTimeout;

  Future<DriverSignOutResult> run() async {
    final outcomes = <SignOutStep, StepOutcome>{};
    final uid = currentUid();

    if (uid == null) {
      outcomes[SignOutStep.offline] = StepOutcome.skipped;
      outcomes[SignOutStep.profileToken] = StepOutcome.skipped;
    } else {
      outcomes[SignOutStep.offline] = await _bounded(goOffline);

      String? token;
      try {
        token = await readDeviceToken().timeout(stepTimeout);
      } catch (_) {
        token = null;
      }
      if (token == null || token.isEmpty) {
        outcomes[SignOutStep.profileToken] = StepOutcome.skipped;
      } else {
        final t = token;
        outcomes[SignOutStep.profileToken] = await _bounded(() async {
          final cleared = await clearProfileTokenIfMatches(uid, t);
          if (!cleared) throw const _Skipped();
        });
      }
    }

    outcomes[SignOutStep.deviceToken] = await _bounded(deleteDeviceToken);

    try {
      await signOut();
      outcomes[SignOutStep.auth] = StepOutcome.done;
    } catch (_) {
      outcomes[SignOutStep.auth] = StepOutcome.failed;
    }

    return DriverSignOutResult(Map.unmodifiable(outcomes));
  }

  Future<StepOutcome> _bounded(Future<void> Function() step) async {
    try {
      await step().timeout(stepTimeout);
      return StepOutcome.done;
    } on _Skipped {
      return StepOutcome.skipped;
    } on TimeoutException {
      return StepOutcome.timedOut;
    } catch (_) {
      return StepOutcome.failed;
    }
  }
}

class _Skipped implements Exception {
  const _Skipped();
}
