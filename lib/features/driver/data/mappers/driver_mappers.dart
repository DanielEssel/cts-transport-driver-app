// data/mappers/driver_mappers.dart
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart';
import '../../domain/entities/driver_stats.dart';
import '../../domain/entities/earnings_summary.dart';
import '../../domain/entities/ride_request.dart';
import '../models/ride_request_dto.dart';


class DriverMapper {
  static DriverProfile fromFirestoreToProfile(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    return DriverProfile(
      uid: doc.id,
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      phone: data['phoneNumber'] ?? '',
      photoUrl: data['photoUrl'],
      isOnline: data['isOnline'] ?? false,
      service: data['serviceType'] ?? 'ride',
      vehicleModel: data['vehicleModel'],
      vehicleType: data['vehicleType'],
      vehiclePlate: data['vehiclePlate'],
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      totalTrips: data['totalTrips'] ?? 0,
      memberSince: (data['memberSince'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
  
  static DriverStats fromFirestoreToStats(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    return DriverStats(
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      completedTrips: data['completedTrips'] ?? 0,
      cancelledTrips: data['cancelledTrips'] ?? 0,
      acceptanceRate: (data['acceptanceRate'] as num?)?.toDouble() ?? 0.0,
      cancellationRate: (data['cancellationRate'] as num?)?.toDouble() ?? 0.0,
      totalDistanceKm: data['totalDistanceKm'] ?? 0,
      totalHoursOnline: data['totalHoursOnline'] ?? 0,
      totalEarnings: (data['totalEarnings'] as num?)?.toDouble() ?? 0.0,
      fiveStarRatings: data['fiveStarRatings'] ?? 0,
      fourStarRatings: data['fourStarRatings'] ?? 0,
      threeStarRatings: data['threeStarRatings'] ?? 0,
      twoStarRatings: data['twoStarRatings'] ?? 0,
      oneStarRatings: data['oneStarRatings'] ?? 0,
    );
  }
  
  static EarningsSummary fromFirestoreToEarnings(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    
    return EarningsSummary(
      todayEarnings: (data['todayEarnings'] as num?)?.toDouble() ?? 0.0,
      weekEarnings: (data['weekEarnings'] as num?)?.toDouble() ?? 0.0,
      monthEarnings: (data['monthEarnings'] as num?)?.toDouble() ?? 0.0,
      totalBalance: (data['totalBalance'] as num?)?.toDouble() ?? 0.0,
      todayTrips: data['todayTrips'] ?? 0,
      weekTrips: data['weekTrips'] ?? 0,
      monthTrips: data['monthTrips'] ?? 0,
      totalTrips: data['totalTrips'] ?? 0,
      pendingPayout: (data['pendingPayout'] as num?)?.toDouble() ?? 0.0,
      availableBalance: (data['availableBalance'] as num?)?.toDouble() ?? 0.0,
      lifetimeEarnings: (data['lifetimeEarnings'] as num?)?.toDouble() ?? 0.0,
      earningsByDay: Map<String, double>.from(data['earningsByDay'] ?? {}),
      earningsByWeek: Map<String, double>.from(data['earningsByWeek'] ?? {}),
      earningsByMonth: Map<String, double>.from(data['earningsByMonth'] ?? {}),
    );
  }
  
  static RideRequest? fromFirestoreToRideRequest(DocumentSnapshot doc) {
    try {
      final dto = RideRequestDTO.fromFirestore(doc);
      return dto.toDomain();
    } catch (e) {
      debugPrint('Error mapping ride request: $e');
      return null;
    }
  }
  
  // Batch mapping for lists
  static List<RideRequest> fromFirestoreToRideRequestList(QuerySnapshot snapshot) {
    return snapshot.docs
        .map((doc) => fromFirestoreToRideRequest(doc))
        .where((request) => request != null)
        .cast<RideRequest>()
        .toList();
  }
}