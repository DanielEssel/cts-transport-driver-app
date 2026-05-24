// lib/core/services/driver_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:geolocator/geolocator.dart';

import '../../features/driver/models/driver_types.dart';

class DriverService {
  // ─────────────────────────────
  // CORE FIREBASE
  // ─────────────────────────────
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;
  static final _rtdb = FirebaseDatabase.instance;

  static String? get uid => _auth.currentUser?.uid;

  static CollectionReference<Map<String, dynamic>> get _drivers =>
      _firestore.collection('drivers');

  static CollectionReference<Map<String, dynamic>> get _requests =>
      _firestore.collection('rideRequests');

  static DocumentReference<Map<String, dynamic>> _driverDoc(String id) =>
      _drivers.doc(id);

  // ─────────────────────────────
  // PROFILE STREAM
  // ─────────────────────────────
  static Stream<DriverProfile?> get profileStream {
  final id = uid;
  if (id == null) return const Stream.empty();

  return _drivers.doc(id).snapshots().map((snap) {
    if (!snap.exists || snap.data() == null) return null;

    return DriverProfile.fromFirestore(snap.data()!, id);
  });
}



static Future<void> createDriverDocument(String phone) async {
  final id = uid;
  if (id == null) return;

  final ref = _drivers.doc(id);
  final snap = await ref.get();

  if (!snap.exists) {
    await ref.set({
      'uid': id,
      'phone': phone,
      'role': null,
      'displayName': null,
      'email': null,
      'photoUrl': null,
      'accountSetupComplete': false,
      'vehicleSetupComplete': false,
      'documentsUploaded': false,
      'isApproved': false,
      'isOnline':       false,
      'isAvailable':    false,
      'serviceType':    'taxi', // default — updated during vehicle setup
      'location':       null,
      'createdAt':      FieldValue.serverTimestamp(),
      'updatedAt':      FieldValue.serverTimestamp(),
    });
  }
}


static Future<void> updateDriver(Map<String, dynamic> data) async {
  final id = uid;
  if (id == null) return;

  await _drivers.doc(id).update({
    ...data,
    'updatedAt': FieldValue.serverTimestamp(),
  });
}

static Future<Map<String, dynamic>?> getDriver() async {
  final id = uid;
  if (id == null) return null;

  final snap = await _drivers.doc(id).get();
  return snap.data();
}

  // ─────────────────────────────
  // EARNINGS STREAM
  // ─────────────────────────────

  static Stream<DocumentSnapshot<Map<String, dynamic>>> get earningsStream {
    final id = uid;
    if (id == null) return const Stream.empty();

    return _driverDoc(id)
        .collection('earnings')
        .doc('summary')
        .snapshots();
  }

  // ─────────────────────────────
  // STATS STREAM
  // ─────────────────────────────
  static Stream<DocumentSnapshot<Map<String, dynamic>>> get statsStream {
    final id = uid;
    if (id == null) return const Stream.empty();

    return _driverDoc(id).collection('stats').doc('summary').snapshots();
  }

  // ─────────────────────────────
  // LOCATION STREAM
  // ─────────────────────────────
  static Stream<Position> get locationStream =>
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 15,
        ),
      );

  // ─────────────────────────────
  // LOCATION UPDATE
  // ─────────────────────────────
  static Future<void> updateLocation(Position pos) async {
    final id = uid;
    if (id == null) return;

    await _driverDoc(id).set({
      'location':          GeoPoint(pos.latitude, pos.longitude), // ← queried by passenger app
      'currentLocation':   GeoPoint(pos.latitude, pos.longitude), // keep for compatibility
      'locationUpdatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _rtdb.ref('drivers/$id/location').set({
      'lat': pos.latitude,
      'lng': pos.longitude,
      'heading': pos.heading,
      'ts': ServerValue.timestamp,
    });
  }

  // ─────────────────────────────
  // ONLINE STATUS + PRESENCE
  // ─────────────────────────────
  static Future<void> setOnlineStatus(
    bool isOnline, {
    GeoPoint? location,
  }) async {
    final id = uid;
    if (id == null) return;

    final driverRef = _driverDoc(id);
    final presenceRef = _rtdb.ref('drivers/$id/presence');

    await driverRef.set({
      'isOnline':       isOnline,
      'isAvailable':    isOnline, // available when online
      'status':         isOnline ? 'online' : 'offline',
      'lastSeen':       FieldValue.serverTimestamp(),
      if (location != null) 'location':        location, // ← queried by passenger app
      if (location != null) 'currentLocation': location,
    }, SetOptions(merge: true));

    await presenceRef.set({
      'online': isOnline,
      'updatedAt': ServerValue.timestamp,
    });

    if (isOnline) {
      await presenceRef.onDisconnect().update({
        'online': false,
        'updatedAt': ServerValue.timestamp,
      });
    }
  }

  // ─────────────────────────────
// REQUEST STREAM (DISPATCH)
// ─────────────────────────────
static Stream<List<Map<String, dynamic>>> pendingRequestsStream(
  DriverServiceType type,
) {
  final id = uid;

  if (id == null) {
    return const Stream.empty();
  }

  return _requests
      .where('status', isEqualTo: 'pending')
      .where('serviceType', isEqualTo: type.name)
      .orderBy('createdAt', descending: true)
      .limit(10)
      .snapshots()
      .map((snapshot) {
    return snapshot.docs
        .where((doc) {
          final data = doc.data();

          final declinedBy =
              List<String>.from(data['declinedBy'] ?? []);

          return !declinedBy.contains(id);
        })
        .map((doc) => {
              'id': doc.id,
              ...doc.data(),
            })
        .toList();
  });
}

  // ─────────────────────────────
  // ACCEPT REQUEST
  // ─────────────────────────────
  static Future<bool> acceptRequest(String requestId) async {
    final id = uid;
    if (id == null) return false;

    final ref = _requests.doc(requestId);

    try {
      return await _firestore.runTransaction((txn) async {
        final snap = await txn.get(ref);

        if (!snap.exists || snap['status'] != 'pending') return false;

        txn.update(ref, {
          'status': 'accepted',
          'driverId': id,
          'acceptedAt': FieldValue.serverTimestamp(),
        });

        return true;
      });
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────
  // DECLINE REQUEST
  // ─────────────────────────────
  static Future<void> declineRequest(String requestId) async {
    final id = uid;
    if (id == null) return;

    await _requests.doc(requestId).update({
      'declinedBy': FieldValue.arrayUnion([id]),
    });
  }

  // ─────────────────────────────
  // LOCATION PERMISSION
  // ─────────────────────────────
  static Future<bool> ensureLocationPermission() async {
    final enabled = await Geolocator.isLocationServiceEnabled();
    if (!enabled) return false;

    var permission = await Geolocator.checkPermission();

    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return permission == LocationPermission.always ||
        permission == LocationPermission.whileInUse;
  }
}