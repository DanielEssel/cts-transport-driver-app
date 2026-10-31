// lib/features/driver/services/driver_session_service.dart
//
// Firebase wiring for DriverSignOut. Use DriverSessionService.signOut() from
// every logout path instead of calling FirebaseAuth.signOut() directly.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../../core/services/location/driver_location_publisher.dart';
import 'driver_runtime_service.dart';
import 'driver_sign_out.dart';

class DriverSessionService {
  DriverSessionService._();

  static Future<DriverSignOutResult>? _inFlight;

  /// Signs the driver out. Concurrent calls share one run, so a double tap
  /// cannot interleave two cleanups.
  static Future<DriverSignOutResult> signOut() {
    return _inFlight ??= _run().whenComplete(() => _inFlight = null);
  }

  static Future<DriverSignOutResult> _run() async {
    final auth = FirebaseAuth.instance;
    final db = FirebaseFirestore.instance;
    final fcm = FirebaseMessaging.instance;

    final result = await DriverSignOut(
      currentUid: () => auth.currentUser?.uid,
      // Stop ALL location publishing (an active job's included) before the
      // offline write: a signed-out device must not keep sharing location.
      goOffline: () async {
        await DriverLocationPublisher.instance.stopAll();
        await DriverRuntimeService().goOffline();
      },
      readDeviceToken: fcm.getToken,
      clearProfileTokenIfMatches: (uid, token) {
        final ref = db.collection('drivers').doc(uid);
        return db.runTransaction<bool>((tx) async {
          final snap = await tx.get(ref);
          if (!snap.exists || snap.data()?['fcmToken'] != token) return false;
          tx.update(ref, {
            'fcmToken': FieldValue.delete(),
            'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          });
          return true;
        });
      },
      deleteDeviceToken: fcm.deleteToken,
      signOut: auth.signOut,
    ).run();

    debugPrint('Driver sign-out: $result');
    return result;
  }
}
