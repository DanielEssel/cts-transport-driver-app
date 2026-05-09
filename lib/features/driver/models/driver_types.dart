// lib/features/driver/models/driver_types.dart
//
// Single source of truth for all driver-related types.
// Delete domain/entities/driver_profile.dart and update all imports to point here.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

// ============================================================================
// Enums
// ============================================================================

enum DriverServiceType { ride, delivery }

enum DriverVehicleType {
  motorbike('motorbike', 'Motorbike (Okada)'),
  aboboyaa('aboboyaa', 'Aboboyaa'),
  miniTruck('mini_truck', 'Mini Truck'),
  pragyia('pragyia', 'Pragyia'),
  taxi('taxi', 'Taxi'),
  quadricycle('quadricycle', 'Quadricycle');

  final String firestoreValue;
  final String label;
  const DriverVehicleType(this.firestoreValue, this.label);
}

enum WeightTier { small, medium, large, bulk }

// ============================================================================
// DriverProfile — merged from driver_types.dart + domain/entities/driver_profile.dart
// ============================================================================

class DriverProfile extends Equatable {
  // ── Identity ──────────────────────────────────────────────────────────────
  final String uid;
  final String? displayName;
  final String? email;
  final String? phone;
  final String? photoUrl;

  // ── Service / Vehicle ─────────────────────────────────────────────────────
  final DriverServiceType service;
  final DriverVehicleType vehicleType;
  final String? vehicleModel;
  final String? vehiclePlate;
  final Map<String, dynamic>? vehicleDetails;

  // ── Status flags ──────────────────────────────────────────────────────────
  final bool isOnline;
  final bool isApproved;
  final bool isVerified;
  final bool accountSetupComplete;
  final bool vehicleSetupComplete;
  final bool documentsUploaded;

  // ── Documents ─────────────────────────────────────────────────────────────
  final Map<String, dynamic> documents; // structured doc map (driver_types)

  // ── Stats ─────────────────────────────────────────────────────────────────
  final double rating;
  final int totalTrips;
  final double acceptanceRate;
  final double cancellationRate;

  // ── Location ──────────────────────────────────────────────────────────────
  final GeoPoint? currentLocation;
  final DateTime? lastLocationUpdate;

  // ── Firestore metadata ────────────────────────────────────────────────────
  final String? role;
  final String? signupStep;
  final DateTime? memberSince;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final DateTime? lastSeen;

  const DriverProfile({
    required this.uid,
    required this.service,
    required this.vehicleType,
    this.displayName,
    this.email,
    this.phone,
    this.photoUrl,
    this.vehicleModel,
    this.vehiclePlate,
    this.vehicleDetails,
    this.isOnline = false,
    this.isApproved = false,
    this.isVerified = false,
    this.accountSetupComplete = false,
    this.vehicleSetupComplete = false,
    this.documentsUploaded = false,
    this.documents = const {},
    this.rating = 0.0,
    this.totalTrips = 0,
    this.acceptanceRate = 0.0,
    this.cancellationRate = 0.0,
    this.currentLocation,
    this.lastLocationUpdate,
    this.role,
    this.signupStep,
    this.memberSince,
    this.createdAt,
    this.updatedAt,
    this.lastSeen,
  });

  // ── Convenience getters ───────────────────────────────────────────────────

  bool get isRide => service == DriverServiceType.ride;
  bool get isDelivery => service == DriverServiceType.delivery;
  bool get isAcceptingRides => isOnline && isVerified;
  bool get isHighRated => rating >= 4.8;
  bool get hasVehicleInfo => vehicleModel != null && vehiclePlate != null;

  String get getDisplayName => displayName ?? 'Driver';
  String get displayNameShort => getDisplayName.split(' ').first;
  String get displayInitial =>
      getDisplayName.isNotEmpty ? getDisplayName[0].toUpperCase() : 'D';
  String get serviceLabel => service.label;
  String get vehicleLabel => vehicleType.label;
  String get vehicleDisplay =>
      hasVehicleInfo ? '$vehicleModel · $vehiclePlate' : 'No vehicle info';
  String get shortUid =>
      uid.length > 6 ? '...${uid.substring(uid.length - 6)}' : uid;

  // ── Document verification ─────────────────────────────────────────────────

  bool get isLicenseVerified => documents['license']?['verified'] == true;
  bool get isInsuranceVerified => documents['insurance']?['verified'] == true;
  bool get isRegistrationVerified =>
      documents['registration']?['verified'] == true;
  bool get isProfileVerified => documents['profile']?['verified'] == true;

  int get verifiedDocumentsCount {
    int count = 0;
    if (isLicenseVerified) count++;
    if (isInsuranceVerified) count++;
    if (isRegistrationVerified) count++;
    if (isProfileVerified) count++;
    return count;
  }

  bool get areAllDocumentsVerified => verifiedDocumentsCount == 4;

  // ── Weight tiers (delivery) ───────────────────────────────────────────────

  List<WeightTier> get allowedWeightTiers {
    if (isRide) return [];
    switch (vehicleType) {
      case DriverVehicleType.motorbike:
        return [WeightTier.small];
      case DriverVehicleType.aboboyaa:
        return [WeightTier.small, WeightTier.medium];
      case DriverVehicleType.pragyia:
      case DriverVehicleType.taxi:
        return [WeightTier.medium, WeightTier.large];
      case DriverVehicleType.miniTruck:
      case DriverVehicleType.quadricycle:
        return [WeightTier.large, WeightTier.bulk];
    }
  }

  // ── Factories ─────────────────────────────────────────────────────────────

  /// Primary factory — use this everywhere (Firestore reads).
  factory DriverProfile.fromFirestore(Map<String, dynamic> data, String uid) {
    return DriverProfile(
      uid: uid,
      service: data['service'] == 'delivery'
          ? DriverServiceType.delivery
          : DriverServiceType.ride,
      vehicleType: _vehicleFromString(data['vehicleType'] as String?),
      displayName: data['displayName'] as String?,
      email: data['email'] as String?,
      phone: data['phone'] as String?,
      photoUrl: data['photoUrl'] as String?,
      vehicleModel: data['vehicleModel'] as String?,
      vehiclePlate: data['vehiclePlate'] as String?,
      vehicleDetails: data['vehicleDetails'] != null
          ? Map<String, dynamic>.from(data['vehicleDetails'] as Map)
          : null,
      isOnline: data['isOnline'] as bool? ?? false,
      isApproved: data['isApproved'] as bool? ?? false,
      isVerified: data['isVerified'] as bool? ?? false,
      accountSetupComplete: data['accountSetupComplete'] as bool? ?? false,
      vehicleSetupComplete: data['vehicleSetupComplete'] as bool? ?? false,
      documentsUploaded: data['documentsUploaded'] as bool? ?? false,
      documents:
          Map<String, dynamic>.from(data['documents'] as Map? ?? {}),
      rating: (data['rating'] ?? 0.0).toDouble(),
      totalTrips: data['totalTrips'] as int? ?? 0,
      acceptanceRate: (data['acceptanceRate'] ?? 0.0).toDouble(),
      cancellationRate: (data['cancellationRate'] ?? 0.0).toDouble(),
      currentLocation: data['currentLocation'] as GeoPoint?,
      lastLocationUpdate: _toDateTime(data['lastLocationUpdate']),
      role: data['role'] as String?,
      signupStep: data['signupStep'] as String?,
      memberSince: _toDateTime(data['memberSince']) ?? DateTime.now(),
      createdAt: _toDateTime(data['createdAt']),
      updatedAt: _toDateTime(data['updatedAt']),
      lastSeen: _toDateTime(data['lastSeen']),
    );
  }

  /// Alias so AuthGate's existing fromMap() calls still compile.
  factory DriverProfile.fromMap(Map<String, dynamic> map, {String? uid}) =>
      DriverProfile.fromFirestore(map, uid ?? map['uid'] as String? ?? '');

  factory DriverProfile.empty() => DriverProfile(
        uid: '',
        service: DriverServiceType.ride,
        vehicleType: DriverVehicleType.motorbike,
        memberSince: DateTime.now(),
      );

  // ── Serialisation ─────────────────────────────────────────────────────────

  Map<String, dynamic> toFirestore() => {
        'uid': uid,
        'service': service.name,
        'vehicleType': vehicleType.firestoreValue,
        'displayName': displayName,
        'email': email,
        'phone': phone,
        'photoUrl': photoUrl,
        'vehicleModel': vehicleModel,
        'vehiclePlate': vehiclePlate,
        'vehicleDetails': vehicleDetails,
        'isOnline': isOnline,
        'isApproved': isApproved,
        'isVerified': isVerified,
        'accountSetupComplete': accountSetupComplete,
        'vehicleSetupComplete': vehicleSetupComplete,
        'documentsUploaded': documentsUploaded,
        'documents': documents,
        'rating': rating,
        'totalTrips': totalTrips,
        'acceptanceRate': acceptanceRate,
        'cancellationRate': cancellationRate,
        'role': role,
        'signupStep': signupStep,
      };

  // ── copyWith ──────────────────────────────────────────────────────────────

  DriverProfile copyWith({
    DriverServiceType? service,
    DriverVehicleType? vehicleType,
    String? displayName,
    String? email,
    String? phone,
    String? photoUrl,
    String? vehicleModel,
    String? vehiclePlate,
    Map<String, dynamic>? vehicleDetails,
    bool? isOnline,
    bool? isApproved,
    bool? isVerified,
    bool? accountSetupComplete,
    bool? vehicleSetupComplete,
    bool? documentsUploaded,
    Map<String, dynamic>? documents,
    double? rating,
    int? totalTrips,
    double? acceptanceRate,
    double? cancellationRate,
    GeoPoint? currentLocation,
    DateTime? lastLocationUpdate,
    String? role,
    String? signupStep,
    DateTime? memberSince,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? lastSeen,
  }) =>
      DriverProfile(
        uid: uid,
        service: service ?? this.service,
        vehicleType: vehicleType ?? this.vehicleType,
        displayName: displayName ?? this.displayName,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        photoUrl: photoUrl ?? this.photoUrl,
        vehicleModel: vehicleModel ?? this.vehicleModel,
        vehiclePlate: vehiclePlate ?? this.vehiclePlate,
        vehicleDetails: vehicleDetails ?? this.vehicleDetails,
        isOnline: isOnline ?? this.isOnline,
        isApproved: isApproved ?? this.isApproved,
        isVerified: isVerified ?? this.isVerified,
        accountSetupComplete: accountSetupComplete ?? this.accountSetupComplete,
        vehicleSetupComplete: vehicleSetupComplete ?? this.vehicleSetupComplete,
        documentsUploaded: documentsUploaded ?? this.documentsUploaded,
        documents: documents ?? this.documents,
        rating: rating ?? this.rating,
        totalTrips: totalTrips ?? this.totalTrips,
        acceptanceRate: acceptanceRate ?? this.acceptanceRate,
        cancellationRate: cancellationRate ?? this.cancellationRate,
        currentLocation: currentLocation ?? this.currentLocation,
        lastLocationUpdate: lastLocationUpdate ?? this.lastLocationUpdate,
        role: role ?? this.role,
        signupStep: signupStep ?? this.signupStep,
        memberSince: memberSince ?? this.memberSince,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
        lastSeen: lastSeen ?? this.lastSeen,
      );

  // ── Equatable ─────────────────────────────────────────────────────────────

  @override
  List<Object?> get props => [
        uid, displayName, email, phone, isOnline, isApproved, isVerified,
        rating, totalTrips, acceptanceRate, cancellationRate,
      ];

  @override
  String toString() =>
      'DriverProfile(uid: $uid, name: $displayName, role: $role, online: $isOnline)';

  // ── Private helpers ───────────────────────────────────────────────────────

  static DriverVehicleType _vehicleFromString(String? v) {
    switch ((v ?? '').toLowerCase()) {
      case 'aboboyaa':
        return DriverVehicleType.aboboyaa;
      case 'mini_truck':
        return DriverVehicleType.miniTruck;
      case 'pragyia':
        return DriverVehicleType.pragyia;
      case 'taxi':
        return DriverVehicleType.taxi;
      case 'quadricycle':
        return DriverVehicleType.quadricycle;
      default:
        return DriverVehicleType.motorbike;
    }
  }

  static DateTime? _toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    try {
      return (value as Timestamp).toDate();
    } catch (_) {
      return null;
    }
  }
}

// ============================================================================
// Extensions
// ============================================================================

extension DriverServiceTypeX on DriverServiceType {
  String get label => switch (this) {
        DriverServiceType.ride => 'Ride Hailing',
        DriverServiceType.delivery => 'Delivery',
      };
}

extension DriverVehicleTypeX on DriverVehicleType {
  String get iconName => switch (this) {
        DriverVehicleType.motorbike => 'ic_motorbike',
        DriverVehicleType.aboboyaa => 'ic_aboboyaa',
        DriverVehicleType.miniTruck => 'ic_mini_truck',
        DriverVehicleType.pragyia => 'ic_pragyia',
        DriverVehicleType.taxi => 'ic_taxi',
        DriverVehicleType.quadricycle => 'ic_quadricycle',
      };
}

extension WeightTierX on WeightTier {
  String get label => switch (this) {
        WeightTier.small => 'Small',
        WeightTier.medium => 'Medium',
        WeightTier.large => 'Large',
        WeightTier.bulk => 'Bulk',
      };
}