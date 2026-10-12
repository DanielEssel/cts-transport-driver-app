// lib/features/driver/services/push_token_store.dart
//
// AUTH-03: saving the FCM token must never create drivers/{uid}.
// It used to be set(merge: true), so merely signing in (even with a
// passenger's number) produced a token-only driver doc, which the backend
// then counted as a driver. Now the token is written with update(), which
// fails on a missing doc; that case is a skip, not an error. The token is
// saved again when the driver goes online (DriverRuntimeService.goOnline)
// and on the next sign-in or token refresh.

import 'package:firebase_core/firebase_core.dart';

/// Returns true if the token was written, false if there is no profile yet.
Future<bool> saveTokenToExistingProfile({
  required Future<void> Function(Map<String, Object?> fields) update,
  required String token,
  required String platform,
  required Object serverTimestamp,
}) async {
  try {
    await update({
      'fcmToken': token,
      'fcmTokenUpdatedAt': serverTimestamp,
      'platform': platform,
    });
    return true;
  } on FirebaseException catch (e) {
    if (e.code == 'not-found') return false;
    rethrow;
  }
}
