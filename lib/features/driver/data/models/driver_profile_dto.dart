// data/models/driver_profile_dto.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart';

class DriverProfileDTO {
  final String id;
  final String displayName;
  final String email;
  final String phoneNumber;
  final String? photoUrl;
  final bool isOnline;
  final String serviceType;
  final String? vehicleModel;
  final String? vehiclePlate;
  final double rating;
  final int totalTrips;
  final DateTime memberSince;
  final GeoPoint? currentLocation;
  final DateTime? lastLocationUpdate;
  final Map<String, dynamic>? vehicleDetails;
  final List<String>? documents;
  final bool isVerified;
  final double acceptanceRate;
  final double cancellationRate;

  DriverProfileDTO({
    required this.id,
    required this.displayName,
    required this.email,
    required this.phoneNumber,
    this.photoUrl,
    this.isOnline = false,
    this.serviceType = 'ride',
    this.vehicleModel,
    this.vehiclePlate,
    this.rating = 0.0,
    this.totalTrips = 0,
    required this.memberSince,
    this.currentLocation,
    this.lastLocationUpdate,
    this.vehicleDetails,
    this.documents,
    this.isVerified = false,
    this.acceptanceRate = 0.0,
    this.cancellationRate = 0.0,
  });

  factory DriverProfileDTO.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return DriverProfileDTO(
      id: doc.id,
      displayName: data['displayName'] ?? '',
      email: data['email'] ?? '',
      phoneNumber: data['phoneNumber'] ?? '',
      photoUrl: data['photoUrl'],
      isOnline: data['isOnline'] ?? false,
      serviceType: data['serviceType'] ?? 'ride',
      vehicleModel: data['vehicleModel'],
      vehiclePlate: data['vehiclePlate'],
      rating: (data['rating'] as num?)?.toDouble() ?? 0.0,
      totalTrips: data['totalTrips'] ?? 0,
      memberSince: (data['memberSince'] as Timestamp?)?.toDate() ?? DateTime.now(),
      currentLocation: data['currentLocation'],
      lastLocationUpdate: (data['lastLocationUpdate'] as Timestamp?)?.toDate(),
      vehicleDetails: data['vehicleDetails'],
      documents: data['documents'] != null ? List<String>.from(data['documents']) : null,
      isVerified: data['isVerified'] ?? false,
      acceptanceRate: (data['acceptanceRate'] as num?)?.toDouble() ?? 0.0,
      cancellationRate: (data['cancellationRate'] as num?)?.toDouble() ?? 0.0,
    );
  }

  DriverProfile toDomain() {
    return DriverProfile(
      uid: id,
      displayName: displayName,
      email: email,
      phoneNumber: phoneNumber,
      photoUrl: photoUrl,
      isOnline: isOnline,
      serviceType: serviceType,
      vehicleModel: vehicleModel,
      vehiclePlate: vehiclePlate,
      rating: rating,
      totalTrips: totalTrips,
      memberSince: memberSince,
      currentLocation: currentLocation,
      lastLocationUpdate: lastLocationUpdate,
      vehicleDetails: vehicleDetails,
      documents: documents,
      isVerified: isVerified,
      acceptanceRate: acceptanceRate,
      cancellationRate: cancellationRate,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'displayName': displayName,
      'email': email,
      'phoneNumber': phoneNumber,
      if (photoUrl != null) 'photoUrl': photoUrl,
      'isOnline': isOnline,
      'serviceType': serviceType,
      if (vehicleModel != null) 'vehicleModel': vehicleModel,
      if (vehiclePlate != null) 'vehiclePlate': vehiclePlate,
      'rating': rating,
      'totalTrips': totalTrips,
      'memberSince': Timestamp.fromDate(memberSince),
      if (currentLocation != null) 'currentLocation': currentLocation,
      if (lastLocationUpdate != null) 'lastLocationUpdate': Timestamp.fromDate(lastLocationUpdate!),
      if (vehicleDetails != null) 'vehicleDetails': vehicleDetails,
      if (documents != null) 'documents': documents,
      'isVerified': isVerified,
      'acceptanceRate': acceptanceRate,
      'cancellationRate': cancellationRate,
    };
  }
}