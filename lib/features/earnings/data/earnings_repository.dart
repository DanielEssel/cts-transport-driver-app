import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/earning_record.dart';

class EarningsRepository {
  final FirebaseFirestore _db;

  EarningsRepository(this._db);

  Future<List<EarningsRecord>> getEarnings(String driverId) async {
    final snapshot = await _db
        .collection('drivers')
        .doc(driverId)
        .collection('earnings')
        .orderBy('date', descending: true)
        .get();

    return snapshot.docs
        .map((doc) => EarningsRecord.fromJson(doc.data()))
        .toList();
  }

  Stream<List<EarningsRecord>> watchEarnings(String driverId) {
    return _db
        .collection('drivers')
        .doc(driverId)
        .collection('earnings')
        .orderBy('date', descending: true)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => EarningsRecord.fromJson(doc.data())).toList());
  }
}