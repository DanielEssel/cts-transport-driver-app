// lib/features/trips/models/trip_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum TripStatus {
  pending,
  accepted,
  arrived,
  inProgress,
  completed,
  cancelled;
  
  String get displayName {
    switch (this) {
      case TripStatus.pending:
        return 'Pending';
      case TripStatus.accepted:
        return 'Accepted';
      case TripStatus.arrived:
        return 'Arrived';
      case TripStatus.inProgress:
        return 'In Progress';
      case TripStatus.completed:
        return 'Completed';
      case TripStatus.cancelled:
        return 'Cancelled';
    }
  }
}

class TripModel {
  final String id;
  final String passengerId;
  final String passengerName;
  final double passengerRating;
  final String? passengerPhotoUrl;
  final String pickupAddress;
  final String dropoffAddress;
  final GeoPoint pickupLocation;
  final GeoPoint dropoffLocation;
  final double fare;
  final double distance;
  final int estimatedDuration;
  final TripStatus status;
  final String? driverId;
  final DateTime createdAt;
  final DateTime? acceptedAt;
  final DateTime? arrivedAt;
  final DateTime? startedAt;
  final DateTime? completedAt;
  final String? verificationCode;
  final double? finalFare;
  final double? totalDistance;

  TripModel({
    required this.id,
    required this.passengerId,
    required this.passengerName,
    required this.passengerRating,
    this.passengerPhotoUrl,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.fare,
    required this.distance,
    required this.estimatedDuration,
    required this.status,
    this.driverId,
    required this.createdAt,
    this.acceptedAt,
    this.arrivedAt,
    this.startedAt,
    this.completedAt,
    this.verificationCode,
    this.finalFare,
    this.totalDistance,
  });

  factory TripModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TripModel(
      id: doc.id,
      passengerId: data['passengerId'] ?? '',
      passengerName: data['passengerName'] ?? 'Unknown',
      passengerRating: (data['passengerRating'] as num?)?.toDouble() ?? 5.0,
      passengerPhotoUrl: data['passengerPhotoUrl'],
      pickupAddress: data['pickupAddress'] ?? '',
      dropoffAddress: data['dropoffAddress'] ?? '',
      pickupLocation: data['pickupLocation'] as GeoPoint? ?? const GeoPoint(0, 0),
      dropoffLocation: data['dropoffLocation'] as GeoPoint? ?? const GeoPoint(0, 0),
      fare: (data['fare'] as num?)?.toDouble() ?? 0.0,
      distance: (data['distance'] as num?)?.toDouble() ?? 0.0,
      estimatedDuration: (data['estimatedDuration'] as num?)?.toInt() ?? 0,
      status: TripStatus.values.firstWhere(
        (e) => e.name == (data['status'] ?? 'pending'),
        orElse: () => TripStatus.pending,
      ),
      driverId: data['driverId'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      acceptedAt: (data['acceptedAt'] as Timestamp?)?.toDate(),
      arrivedAt: (data['arrivedAt'] as Timestamp?)?.toDate(),
      startedAt: (data['startedAt'] as Timestamp?)?.toDate(),
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      verificationCode: data['verificationCode'],
      finalFare: (data['finalFare'] as num?)?.toDouble(),
      totalDistance: (data['totalDistance'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'passengerId': passengerId,
      'passengerName': passengerName,
      'passengerRating': passengerRating,
      'passengerPhotoUrl': passengerPhotoUrl,
      'pickupAddress': pickupAddress,
      'dropoffAddress': dropoffAddress,
      'pickupLocation': pickupLocation,
      'dropoffLocation': dropoffLocation,
      'fare': fare,
      'distance': distance,
      'estimatedDuration': estimatedDuration,
      'status': status.name,
      'driverId': driverId,
      'createdAt': Timestamp.fromDate(createdAt),
      'acceptedAt': acceptedAt != null ? Timestamp.fromDate(acceptedAt!) : null,
      'arrivedAt': arrivedAt != null ? Timestamp.fromDate(arrivedAt!) : null,
      'startedAt': startedAt != null ? Timestamp.fromDate(startedAt!) : null,
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'verificationCode': verificationCode,
      'finalFare': finalFare,
      'totalDistance': totalDistance,
    };
  }
}