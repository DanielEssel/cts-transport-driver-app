// domain/repositories/driver_repository.dart
import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart';
import '../../domain/entities/driver_stats.dart';
import '../../domain/entities/earnings_summary.dart';
import '../../domain/entities/ride_request.dart';

abstract class DriverRepository {
  // Getters
  String get currentDriverId;

Future<String> getCurrentDriverId();

  // Stream-based (Real-time)
  Stream<DriverProfile> watchDriverProfile(String driverId);
  Stream<DriverStats> watchDriverStats(String driverId);
  Stream<EarningsSummary> watchEarningsSummary(String driverId);
  Stream<int> watchUnreadNotificationsCount(String driverId);
  Stream<List<RideRequest>> watchPendingRequests(String driverId, String serviceType);

  // Future-based (Initial Load & Actions)
  Future<bool> getOnlineStatus(String driverId);
  Future<DriverStats> getDriverStats(String driverId);
  Future<EarningsSummary> getEarnings(String driverId);
  Future<int> getUnreadNotifications(String driverId);
  
  Future<void> setOnlineStatus({required String driverId, required bool isOnline, GeoPoint? location});
  Future<void> updateLocation({required String driverId, required GeoPoint location});
  Future<void> markNotificationsRead(String driverId);
  
  Future<void> acceptRequest({required String driverId, required String requestId});
  Future<void> declineRequest({required String driverId, required String requestId});

 

  Future<DriverProfile> getDriverProfile(
    String driverId,
  );

  // ─────────────────────────────────────────────
  // STATS & EARNINGS
  // ─────────────────────────────────────────────


  Future<EarningsSummary> getEarningsSummary(
    String driverId,
  );



  Future<bool> checkLocationPermission();

  Future<bool> requestLocationPermission();

  

  Future<void> dismissRequest({
    required String driverId,
    required String requestId,
  });
}
