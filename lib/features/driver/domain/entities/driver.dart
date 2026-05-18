import 'package:cloud_firestore/cloud_firestore.dart';

class Driver {
  final String id;
  final String name;
  final String phone;
  final bool isOnline;
  final bool isApproved;
  final String vehicleType;
  final GeoPoint? location;
  final String? fcmToken;
  final double rating;

  const Driver({
    required this.id,
    required this.name,
    required this.phone,
    required this.isOnline,
    required this.isApproved,
    required this.vehicleType,
    this.location,
    this.fcmToken,
    this.rating = 5,
  });

  factory Driver.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return Driver(
      id: doc.id,
      name: data['displayName'] ?? '',
      phone: data['phone'] ?? '',
      isOnline: data['isOnline'] ?? false,
      isApproved: data['isApproved'] ?? false,
      vehicleType: data['vehicleType'] ?? '',
      location: data['location'],
      fcmToken: data['fcmToken'],
      rating: (data['rating'] ?? 5).toDouble(),
    );
  }
}