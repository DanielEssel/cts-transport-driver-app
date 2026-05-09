import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class EarningsProvider {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<QuerySnapshot> getCompletedTrips(DateTime startDate) async {
    final driverId = _auth.currentUser?.uid;
    if (driverId == null) throw Exception('Not logged in');

    return await _firestore
        .collection('trips')
        .where('driverId', isEqualTo: driverId)
        .where('status', isEqualTo: 'completed')
        .where('completedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .orderBy('completedAt', descending: true)
        .get();
  }

  Stream<DocumentSnapshot> streamDriverStats() {
    final driverId = _auth.currentUser?.uid;
    if (driverId == null) throw Exception('Not logged in');
    
    return _firestore.collection('drivers').doc(driverId).snapshots();
  }

  Future<Map<String, dynamic>> getEarningsSummary(DateTime startDate) async {
    final trips = await getCompletedTrips(startDate);
    
    double totalGross = 0;
    int totalTrips = trips.docs.length;
    
    for (var doc in trips.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final fare = (data['finalFare'] ?? data['fare'] as num).toDouble();
      totalGross += fare;
    }
    
    final platformFee = totalGross * 0.15;
    final netEarnings = totalGross - platformFee;
    
    return {
      'totalGross': totalGross,
      'totalTrips': totalTrips,
      'platformFee': platformFee,
      'netEarnings': netEarnings,
      'avgPerTrip': totalTrips > 0 ? netEarnings / totalTrips : 0,
    };
  }
}