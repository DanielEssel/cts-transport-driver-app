// lib/features/trips/models/trip_model.dart
import 'package:cloud_firestore/cloud_firestore.dart';

enum TripStatus {
  searching,
  tripAccepted,
  driverArrived,
  tripStarted,
  completed,
  cancelledByDriver,
  cancelledByPassenger,
  noDriversAvailable,
  expired;

  static TripStatus fromFirestore(String? value) => switch (value) {
    'searching'            => searching,
    'tripAccepted'         => tripAccepted,
    'driverArrived'        => driverArrived,
    'tripStarted'          => tripStarted,
    'completed'            => completed,
    'cancelledByDriver'    => cancelledByDriver,
    'cancelledByPassenger' => cancelledByPassenger,
    'noDriversAvailable'   => noDriversAvailable,
    'expired'              => expired,
    _                      => searching,
  };

  String get firestoreValue => switch (this) {
    searching            => 'searching',
    tripAccepted         => 'tripAccepted',
    driverArrived        => 'driverArrived',
    tripStarted          => 'tripStarted',
    completed            => 'completed',
    cancelledByDriver    => 'cancelledByDriver',
    cancelledByPassenger => 'cancelledByPassenger',
    noDriversAvailable   => 'noDriversAvailable',
    expired              => 'expired',
  };

  String get displayName => switch (this) {
    searching            => 'Searching',
    tripAccepted         => 'Driver on the way',
    driverArrived        => 'Driver arrived',
    tripStarted          => 'Trip in progress',
    completed            => 'Completed',
    cancelledByDriver    => 'Cancelled by driver',
    cancelledByPassenger => 'Cancelled',
    noDriversAvailable   => 'No drivers available',
    expired              => 'Expired',
  };
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
  final String  serviceType;
  final String? driverName;
  final String? driverPhone;
  final String? driverPlate;
  final double? driverRating;
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
    this.serviceType = 'taxi',
    this.driverName,
    this.driverPhone,
    this.driverPlate,
    this.driverRating,
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
      id:               doc.id,
      passengerId:      data['passengerId']      as String? ?? '',
      passengerName:    data['passengerName']    as String? ?? 'Passenger',
      passengerRating:  (data['passengerRating'] as num?)?.toDouble() ?? 5.0,
      passengerPhotoUrl: data['passengerPhotoUrl'] as String?,
      pickupAddress:    data['pickupAddress']    as String? ?? '',
      dropoffAddress:   data['dropoffAddress']   as String? ?? '',
      pickupLocation:   data['pickupLocation']   as GeoPoint? ?? const GeoPoint(0, 0),
      dropoffLocation:  data['dropoffLocation']  as GeoPoint? ?? const GeoPoint(0, 0),
      fare:             (data['estimatedFare']   as num?)?.toDouble() ??
                        (data['fare']            as num?)?.toDouble() ?? 0.0,
      distance:         (data['distance']        as num?)?.toDouble() ?? 0.0,
      estimatedDuration: (data['estimatedDuration'] as num?)?.toInt() ?? 0,
      status:           TripStatus.fromFirestore(data['status'] as String?),
      driverId:         data['driverId']         as String?,
      serviceType:      data['serviceType']      as String? ?? 'taxi',
      driverName:       data['driverName']       as String?,
      driverPhone:      data['driverPhone']      as String?,
      driverPlate:      data['driverPlate']      as String?,
      driverRating:     (data['driverRating']    as num?)?.toDouble(),
      createdAt:        (data['createdAt']       as Timestamp?)?.toDate() ?? DateTime.now(),
      acceptedAt:       (data['acceptedAt']      as Timestamp?)?.toDate(),
      arrivedAt:        (data['arrivedAt']       as Timestamp?)?.toDate(),
      startedAt:        (data['startedAt']       as Timestamp?)?.toDate(),
      completedAt:      (data['completedAt']     as Timestamp?)?.toDate(),
      verificationCode: data['verificationCode'] as String?,
      finalFare:        (data['finalFare']       as num?)?.toDouble(),
      totalDistance:    (data['totalDistance']   as num?)?.toDouble(),
    );
  }
}
