import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';

import '../../../core/services/location/driver_location_publisher.dart';

class DriverRuntimeService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  // The only GPS stream belongs to DriverLocationPublisher (idle while no job
  // runs, the job's stream during one; both also update this profile), so
  // goOffline() on any instance stops the one started by goOnline().
  final DriverLocationPublisher _publisher = DriverLocationPublisher.instance;

  String get uid => _auth.currentUser!.uid;

  /// Call when driver taps GO ONLINE.
  ///
  /// The driver is only marked online/available after a valid
  /// current location has been written. This ensures backend
  /// dispatch always has a location to evaluate.
  Future<void> goOnline() async {
    // 1. Get FCM token.
    final token = await FirebaseMessaging.instance.getToken();

    // 2. Request/check location permission.
    final permission = await Geolocator.requestPermission();

    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception('Location permission denied');
    }

    // 3. Get the driver's current location BEFORE marking them online.
    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
      ),
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw Exception(
        'Unable to get your current location. Please try again.',
      ),
    );

    final location = GeoPoint(
      position.latitude,
      position.longitude,
    );

    // 5. Write location + availability atomically from the dispatcher's
    // perspective. The backend can now safely evaluate this driver.
    await _db.collection('drivers').doc(uid).set({
      'location': location,
      'currentLocation': location,
      'lastSeen': FieldValue.serverTimestamp(),
      'lastLocationUpdate': FieldValue.serverTimestamp(),
      'isOnline': true,
      'isAvailable': true,
      // With its save time, so a late backend event for an older save of
      // this device's token never takes it from this driver
      // (onDriverTokenSaved). A missing token leaves the saved one alone.
      if (token != null) 'fcmToken': token,
      if (token != null) 'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
      'lastStatusChange': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    _publisher.noteProfileWritten(position.latitude, position.longitude);

    // 6. Continuous, best-effort location updates to the profile through the
    // shared publisher (same stream settings as before: high accuracy, 10 m).
    // No foreground service while idle: Android may throttle these updates
    // heavily while the app is in the background.
    await _publisher.startIdle();
  }

  /// The driver was already online when the app (re)started: resume idle
  /// location updates without rewriting the online flags or the FCM token.
  Future<void> resumeOnlineTracking() => _publisher.startIdle();

  /// Call when driver goes offline.
  Future<void> goOffline() async {
    await _publisher.stopIdle();

    await _db.collection('drivers').doc(uid).update({
      'isOnline': false,
      'isAvailable': false,
      'lastStatusChange': FieldValue.serverTimestamp(),
    });
  }
}
