import 'package:cloud_firestore/cloud_firestore.dart';

class DriverRemoteDataSource {
  final FirebaseFirestore firestore;
  
  DriverRemoteDataSource({required this.firestore});
  
  // Helper for consistent pathing
  DocumentReference _driverDoc(String uid) => firestore.collection('drivers').doc(uid);
  
  // ──────────────────────────────────────────────────────────────────────────
  // ONE-TIME FETCHES (Futures)
  // ──────────────────────────────────────────────────────────────────────────
  
  Future<DocumentSnapshot<Map<String, dynamic>>> getDriverProfile(String driverId) async {
    return await _driverDoc(driverId).get() as DocumentSnapshot<Map<String, dynamic>>;
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getDriverStats(
    String driverId) async {
  return await _driverDoc(driverId).get()
      as DocumentSnapshot<Map<String, dynamic>>;
}

Future<DocumentSnapshot<Map<String, dynamic>>> getEarningsSummary(
    String driverId) async {
  return await _driverDoc(driverId).get()
      as DocumentSnapshot<Map<String, dynamic>>;
}

  Future<QuerySnapshot> getUnreadNotifications(String driverId) async {
    return await _driverDoc(driverId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .get();
  }

  // ──────────────────────────────────────────────────────────────────────────
  // REAL-TIME UPDATES (Streams)
  // ──────────────────────────────────────────────────────────────────────────
  
  Stream<DocumentSnapshot> watchDriverProfile(String driverId) {
    return _driverDoc(driverId).snapshots();
  }
  
  Stream<DocumentSnapshot> watchDriverStats(String driverId) {
    return _driverDoc(driverId).snapshots();
  }
  
  Stream<DocumentSnapshot> watchEarningsSummary(String driverId) {
    return _driverDoc(driverId).snapshots();
  }
  
  Stream<QuerySnapshot> watchUnreadNotificationsCount(String driverId) {
    return _driverDoc(driverId)
        .collection('notifications')
        .where('read', isEqualTo: false)
        .snapshots();
  }

  
 Stream<QuerySnapshot> watchPendingRequests(String driverId, String serviceType) {
    return firestore
        .collection('ride_requests')
        .where('status', isEqualTo: 'pending')
        .where('serviceType', isEqualTo: serviceType)
        // Use whereNotIn to filter out this driver's ID from the declined list
        .where('declinedBy', whereNotIn: [driverId]) 
        .orderBy('declinedBy') // Firestore requires ordering by the inequality field first
        .orderBy('createdAt', descending: true)
        .limit(20)
        .snapshots();
  }
  
  // ──────────────────────────────────────────────────────────────────────────
  // ACTIONS
  // ──────────────────────────────────────────────────────────────────────────
  
  Future<void> setOnlineStatus(String driverId, bool isOnline, {GeoPoint? location}) async {
    final data = {
      'isOnline':          isOnline,
      'isAvailable':       isOnline, // available when online
      'lastStatusChange':  FieldValue.serverTimestamp(),
      if (location != null) 'location': location,         // ← use 'location' not 'currentLocation'
      if (location != null) 'currentLocation': location,  // keep both for compatibility
    };
    await _driverDoc(driverId).update(data);
  }
  
  Future<void> updateLocation(String driverId, GeoPoint location) async {
    await _driverDoc(driverId).update({
      'location':          location, // ← primary field queried by passenger app
      'currentLocation':   location, // keep for compatibility
      'lastLocationUpdate': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markNotificationsAsRead(String driverId) async {
    final batch = firestore.batch();
    final unread = await getUnreadNotifications(driverId);
    for (var doc in unread.docs) {
      batch.update(doc.reference, {'read': true});
    }
    await batch.commit();
  }
  
  Future<void> acceptRequest(String driverId, String requestId) async {
    await firestore.runTransaction((transaction) async {
      final requestRef = firestore.collection('ride_requests').doc(requestId);
      final requestDoc = await transaction.get(requestRef);
      
      if (!requestDoc.exists) throw Exception('Request not found');
      
      final requestData = requestDoc.data()!;
      if (requestData['status'] != 'pending') {
        throw Exception('already accepted'); // Repository catches this string
      }
      
      transaction.update(requestRef, {
        'status': 'accepted',
        'driverId': driverId,
        'acceptedAt': FieldValue.serverTimestamp(),
      });
      
      final tripRef = firestore.collection('active_trips').doc();
      transaction.set(tripRef, {
        'id': tripRef.id,
        'requestId': requestId,
        'driverId': driverId,
        'status': 'accepted',
        'startedAt': FieldValue.serverTimestamp(),
      });
    });
  }
  
  Future<void> declineRequest(String driverId, String requestId) async {
    await firestore.collection('ride_requests').doc(requestId).update({
      'declinedBy': FieldValue.arrayUnion([driverId]),
    });
  }
  
  Future<void> dismissRequest(String driverId, String requestId) async {
    await _driverDoc(driverId)
        .collection('dismissed_requests')
        .doc(requestId)
        .set({'dismissedAt': FieldValue.serverTimestamp()});
  }
}