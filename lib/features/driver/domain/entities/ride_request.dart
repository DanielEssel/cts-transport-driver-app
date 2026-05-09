// domain/entities/ride_request.dart
import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'request_type.dart';

class RideRequest extends Equatable {
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
  final RequestType requestType;
  final DateTime createdAt;
  final int? passengerCount;

  const RideRequest({
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

  bool get hasPassengerCount => passengerCount != null && passengerCount! > 0;

  @override
  List<Object?> get props => [
    id, passengerId, passengerName, fareAmount, requestType, createdAt
  ];

  RideRequest copyWith({
    String? id,
    String? passengerId,
    String? passengerName,
    String? passengerPhotoUrl,
    double? passengerRating,
    String? fromAddress,
    String? toAddress,
    GeoPoint? fromLocation,
    GeoPoint? toLocation,
    double? fareAmount,
    double? distanceKm,
    int? estimatedMinutes,
    RequestType? requestType,
    DateTime? createdAt,
    int? passengerCount,
  }) {
    return RideRequest(
      id: id ?? this.id,
      passengerId: passengerId ?? this.passengerId,
      passengerName: passengerName ?? this.passengerName,
      passengerPhotoUrl: passengerPhotoUrl ?? this.passengerPhotoUrl,
      passengerRating: passengerRating ?? this.passengerRating,
      fromAddress: fromAddress ?? this.fromAddress,
      toAddress: toAddress ?? this.toAddress,
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
      fareAmount: fareAmount ?? this.fareAmount,
      distanceKm: distanceKm ?? this.distanceKm,
      estimatedMinutes: estimatedMinutes ?? this.estimatedMinutes,
      requestType: requestType ?? this.requestType,
      createdAt: createdAt ?? this.createdAt,
      passengerCount: passengerCount ?? this.passengerCount,
    );
  }
}
