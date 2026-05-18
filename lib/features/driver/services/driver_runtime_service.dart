import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:geolocator/geolocator.dart';

class DriverRuntimeService {
  final _db = FirebaseFirestore.instance;
  final _auth = FirebaseAuth.instance;

  StreamSubscription<Position>? _positionStream;

  String get uid => _auth.currentUser!.uid;

  /// Call when driver taps GO ONLINE
  Future<void> goOnline() async {
    // 1️⃣ Save FCM token
    final token = await FirebaseMessaging.instance.getToken();

    // 2️⃣ Request location permission
    final permission = await Geolocator.requestPermission();
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      throw Exception("Location permission denied");
    }

    // 3️⃣ Mark driver online
    await _db.collection('drivers').doc(uid).set({
      'isOnline': true,
      'isAvailable': true,
      'fcmToken': token,
      'lastStatusChange': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // 4️⃣ Start realtime GPS updates
    _positionStream = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 10,
      ),
    ).listen((pos) async {
      await _db.collection('drivers').doc(uid).set({
        'location': GeoPoint(pos.latitude, pos.longitude),
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  /// Call when driver goes offline
  Future<void> goOffline() async {
    await _positionStream?.cancel();

    await _db.collection('drivers').doc(uid).update({
      'isAvailable': false,
      'lastStatusChange': FieldValue.serverTimestamp(),
    });
  }
}