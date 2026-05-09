// domain/repositories/driver_repository.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../entities/driver_stats.dart';
import '../entities/ride_request.dart';
import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart';
import '../entities/earnings_summary.dart';

abstract class DriverRepository {
  // Profile streams
  String get currentDriverId;
  
  Stream<DriverProfile> watchDriverProfile(String driverId);
  Future<DriverProfile> getDriverProfile(String driverId);
  Future<DriverStats> getDriverStats(String driverId);
  Future<EarningsSummary> getEarningsSummary(String driverId);
  Future<int> getUnreadNotifications(String driverId);
  Future<bool> getOnlineStatus(String driverId);
  Future<String> getCurrentDriverId();
  Future<void> getEarnings(String driverId);
  Future<void> markNotificationsRead(String driverId);
  Future<void> updateLocation({required String driverId, required GeoPoint location});

  
  

  // Request streams
  Stream<List<RideRequest>> watchPendingRequests({
    required String driverId,
    required String serviceType,
  });

  Stream<int> watchUnreadNotificationsCount(String driverId);
  // Stream-based methods for real-time UI
  Stream<DriverStats> watchDriverStats(String driverId);
  Stream<EarningsSummary> watchEarningsSummary(String driverId);


  // Actions
  Future<void> setOnlineStatus({
    required String driverId,
    required bool isOnline,
    GeoPoint? location,

  });


  Future<void> acceptRequest({
    required String driverId,
    required String requestId,
  });

  Future<void> declineRequest({
    required String driverId,
    required String requestId,
  });

  Future<void> dismissRequest({
    required String driverId,
    required String requestId,
  });

  // Permission & location
  Future<bool> checkLocationPermission();
  Future<bool> requestLocationPermission();
}

