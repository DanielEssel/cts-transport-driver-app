// data/repositories/driver_repository_impl.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';

import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart';
import '../../domain/entities/driver_stats.dart';
import '../../domain/entities/earnings_summary.dart';
import '../../domain/entities/ride_request.dart';
import '../../domain/failures/driver_failures.dart';
import '../../domain/repositories/driver_repository.dart'; // Import the interface from domain
import '../datasources/driver_remote_datasource.dart';
import '../mappers/driver_mappers.dart';
import '../../domain/entities/driver.dart';



class DriverRepositoryImpl implements DriverRepository {
  final DriverRemoteDataSource remoteDataSource;
  final FirebaseAuth firebaseAuth;

  DriverRepositoryImpl({
    required this.remoteDataSource, 
    required this.firebaseAuth,
  });

  @override
  String get currentDriverId => firebaseAuth.currentUser?.uid ?? '';

  @override
  Future<String> getCurrentDriverId() async => currentDriverId;

  // --- Profile ---
  @override
  Stream<DriverProfile> watchDriverProfile(String driverId) =>
      remoteDataSource.watchDriverProfile(driverId).map(DriverMapper.fromFirestoreToProfile);

  @override
  Future<DriverProfile> getDriverProfile(String driverId) async {
    final doc = await remoteDataSource.getDriverProfile(driverId);
    return DriverMapper.fromFirestoreToProfile(doc);
  }

  @override
Future<Driver> getDriver(String driverId) async {
  final doc = await FirebaseFirestore.instance
      .collection('drivers')
      .doc(driverId)
      .get();

  if (!doc.exists) {
    throw Exception('Driver profile not found');
  }

  return Driver.fromFirestore(doc);
}

  @override
  Future<EarningsSummary> getEarningsSummary(String driverId) async {
    final doc = await remoteDataSource.getEarningsSummary(driverId);
    return DriverMapper.fromFirestoreToEarnings(doc);
  }

  // --- Stats & Earnings ---
  @override
  Stream<DriverStats> watchDriverStats(String driverId) =>
      remoteDataSource.watchDriverStats(driverId).map(DriverMapper.fromFirestoreToStats);

  @override
  Stream<EarningsSummary> watchEarningsSummary(String driverId) =>
      remoteDataSource.watchEarningsSummary(driverId).map(DriverMapper.fromFirestoreToEarnings);

  @override
  Future<DriverStats> getDriverStats(String driverId) async {
    final doc = await remoteDataSource.getDriverStats(driverId);
    return DriverMapper.fromFirestoreToStats(doc);
  }

  @override
Future<EarningsSummary> getEarnings(String driverId) async {
  final doc = await remoteDataSource.getEarningsSummary(driverId);
  return DriverMapper.fromFirestoreToEarnings(doc);
}

  // --- Notifications ---
  @override
  Stream<int> watchUnreadNotificationsCount(String driverId) =>
      remoteDataSource.watchUnreadNotificationsCount(driverId).map((s) => s.docs.length);

  @override
  Future<int> getUnreadNotifications(String driverId) async {
    final snapshot = await remoteDataSource.getUnreadNotifications(driverId);
    return snapshot.docs.length;
  }

  @override
  Future<void> markNotificationsRead(String driverId) async {
    await remoteDataSource.markNotificationsAsRead(driverId);
  }

  // --- Online Status & Location ---
  @override
  Future<bool> getOnlineStatus(String driverId) async {
    final doc = await remoteDataSource.getDriverProfile(driverId);
    return doc.data()?['isOnline'] ?? false;
  }

  @override
  Future<void> setOnlineStatus({required String driverId, required bool isOnline, GeoPoint? location}) async {
    await remoteDataSource.setOnlineStatus(driverId, isOnline, location: location);
  }

  @override
  Future<void> updateLocation({required String driverId, required GeoPoint location}) async {
    await remoteDataSource.updateLocation(driverId, location);
  }

  @override
  Future<bool> checkLocationPermission() async {
    final permission = await Geolocator.checkPermission();
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  @override
  Future<bool> requestLocationPermission() async {
    final permission = await Geolocator.requestPermission();
    return permission == LocationPermission.always || permission == LocationPermission.whileInUse;
  }

  // --- Requests ---
  @override
  Stream<List<RideRequest>> watchPendingRequests({required String driverId, required String serviceType}) {
    return remoteDataSource.watchPendingRequests(driverId, serviceType).map((snapshot) {
      return snapshot.docs
          .map((doc) => DriverMapper.fromFirestoreToRideRequest(doc))
          .whereType<RideRequest>()
          .toList();
    });
  }

  @override
  Future<void> acceptRequest({required String driverId, required String requestId}) async {
    try {
      await remoteDataSource.acceptRequest(driverId, requestId);
    } catch (e) {
      if (e.toString().contains('already accepted')) throw const RequestAlreadyAccepted();
      rethrow;
    }
  }

  @override
  Future<void> declineRequest({required String driverId, required String requestId}) async {
    await remoteDataSource.declineRequest(driverId, requestId);
  }

  @override
  Future<void> dismissRequest({required String driverId, required String requestId}) async {
    await remoteDataSource.dismissRequest(driverId, requestId);
  }
}