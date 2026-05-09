// data/models/ride_request_dto.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/ride_request.dart';
import '../../domain/entities/request_type.dart';

class RideRequestDTO {
  final String id;
  final String passengerId;
  final String passengerName;
  final String? passengerPhotoUrl;
  final double passengerRating;
  final String fromAddress;
  final String toAddress;
  final GeoPoint fromLocation;
  final GeoPoint toLocation;
  final double fareAmount;
  final double distanceKm;
  final int estimatedMinutes;
  final String requestType;
  final DateTime createdAt;
  final int? passengerCount;

  RideRequestDTO({
    required this.id,
    required this.passengerId,
    required this.passengerName,
    this.passengerPhotoUrl,
    this.passengerRating = 5.0,
    required this.fromAddress,
    required this.toAddress,
    required this.fromLocation,
    required this.toLocation,
    required this.fareAmount,
    required this.distanceKm,
    required this.estimatedMinutes,
    required this.requestType,
    required this.createdAt,
    this.passengerCount,
  });

  factory RideRequestDTO.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return RideRequestDTO(
      id: doc.id,
      passengerId: data['passengerId'] ?? '',
      passengerName: data['passengerName'] ?? 'Unknown',
      passengerPhotoUrl: data['passengerPhotoUrl'],
      passengerRating: (data['passengerRating'] as num?)?.toDouble() ?? 5.0,
      fromAddress: data['fromAddress'] ?? '',
      toAddress: data['toAddress'] ?? '',
      fromLocation: data['fromLocation'] as GeoPoint? ?? const GeoPoint(0, 0),
      toLocation: data['toLocation'] as GeoPoint? ?? const GeoPoint(0, 0),
      fareAmount: (data['fareAmount'] as num?)?.toDouble() ?? 0.0,
      distanceKm: (data['distanceKm'] as num?)?.toDouble() ?? 0.0,
      estimatedMinutes: (data['estimatedMinutes'] as num?)?.toInt() ?? 0,
      requestType: data['requestType'] ?? 'ride',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      passengerCount: (data['passengerCount'] as num?)?.toInt(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'passengerId': passengerId,
      'passengerName': passengerName,
      'passengerPhotoUrl': passengerPhotoUrl,
      'passengerRating': passengerRating,
      'fromAddress': fromAddress,
      'toAddress': toAddress,
      'fromLocation': fromLocation,
      'toLocation': toLocation,
      'fareAmount': fareAmount,
      'distanceKm': distanceKm,
      'estimatedMinutes': estimatedMinutes,
      'requestType': requestType,
      'createdAt': Timestamp.fromDate(createdAt),
      'passengerCount': passengerCount,
    };
  }

  RideRequest toDomain() {
    return RideRequest(
      id: id,
      passengerId: passengerId,
      passengerName: passengerName,
      passengerPhotoUrl: passengerPhotoUrl,
      passengerRating: passengerRating,
      fromAddress: fromAddress,
      toAddress: toAddress,
      fromLocation: fromLocation,
      toLocation: toLocation,
      fareAmount: fareAmount,
      distanceKm: distanceKm,
      estimatedMinutes: estimatedMinutes,
      requestType: RequestType.values.firstWhere(
        (e) => e.name == requestType,
        orElse: () => RequestType.ride,
      ),
      createdAt: createdAt,
      passengerCount: passengerCount,
    );
  }
}