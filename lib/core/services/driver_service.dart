// lib/core/services/driver_service.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/driver/models/driver_types.dart';
import 'driver_profile_defaults.dart';

class DriverService {
  // ─────────────────────────────
  // CORE FIREBASE
  // ─────────────────────────────
  static final _firestore = FirebaseFirestore.instance;
  static final _auth = FirebaseAuth.instance;

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
  // Server copy: a cached "missing" must not trigger a full overwrite.
  final snap = await ref.get(const GetOptions(source: Source.server));

  if (!snap.exists) {
    await ref.set({
      ...newDriverDefaults(id, phone),
      'createdAt':      FieldValue.serverTimestamp(),
      'updatedAt':      FieldValue.serverTimestamp(),
    });
    return;
  }

  // Existing doc (e.g. token-only, from older app versions): add only the
  // missing owner-writable defaults; never overwrite what is there.
  final missing = missingOwnerDefaults(snap.data() ?? {}, id, phone);
  if (missing.isNotEmpty) {
    await ref.update({
      ...missing,
      'updatedAt': FieldValue.serverTimestamp(),
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
}
