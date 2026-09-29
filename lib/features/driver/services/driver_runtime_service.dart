import 'dart:async';
import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';

class DriverRuntimeService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  StreamSubscription<Position>? _positionStream;

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

    // 4. Cancel any previous GPS stream before starting a new one.
    await _positionStream?.cancel();
    _positionStream = null;

    // 5. Write location + availability atomically from the dispatcher's
    // perspective. The backend can now safely evaluate this driver.
    await _db.collection('drivers').doc(uid).set({
      'location': location,
      'currentLocation': location,
      'lastSeen': FieldValue.serverTimestamp(),
      'lastLocationUpdate': FieldValue.serverTimestamp(),
      'isOnline': true,
      'isAvailable': true,
      'fcmToken': token,
      'lastStatusChange': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 6. Start continuous GPS updates.
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen(
      (pos) async {
        final updatedLocation = GeoPoint(
          pos.latitude,
          pos.longitude,
        );

        try {
          await _db.collection('drivers').doc(uid).set({
            'location': updatedLocation,
            'currentLocation': updatedLocation,
            'lastSeen': FieldValue.serverTimestamp(),
            'lastLocationUpdate': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        } catch (e) {
          // Do not terminate the GPS stream because of a transient
          // Firestore write failure.
          debugPrint('Driver location update failed: $e');
        }
      },
      onError: (error) {
        debugPrint('Driver GPS stream error: $error');
      },
    );
  }

  /// Call when driver goes offline.
  Future<void> goOffline() async {
    await _positionStream?.cancel();
    _positionStream = null;

    await _db.collection('drivers').doc(uid).update({
      'isOnline': false,
      'isAvailable': false,
      'lastStatusChange': FieldValue.serverTimestamp(),
    });
  }
}
