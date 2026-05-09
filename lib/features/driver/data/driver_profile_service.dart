// lib/features/driver/data/driver_profile_service.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/driver_types.dart';

class DriverProfileService {
  final _auth = FirebaseAuth.instance;
  final _db = FirebaseFirestore.instance;

  Stream<DriverProfile> streamProfile() {
    final uid = _auth.currentUser!.uid;
    return _db.collection('drivers').doc(uid).snapshots().map((doc) {
      if (!doc.exists) {
        throw Exception("Driver profile missing in Firestore");
      }
      return DriverProfile.fromFirestore(doc.data()!, uid);
    });
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}