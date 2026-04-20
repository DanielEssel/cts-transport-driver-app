// features/jobs/models/delivery_request.dart

class ParcelType {
  static const document = ParcelType._internal('Document', '📄');
  static const food = ParcelType._internal('Food', '🍕');
  static const furniture = ParcelType._internal('Furniture', '🪑');
  static const electronics = ParcelType._internal('Electronics', '📱');
  static const other = ParcelType._internal('Other', '📦');
  
  final String label;
  final String icon;
  
  const ParcelType._internal(this.label, this.icon);
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ParcelType && other.label == label;
  }
  
  @override
  int get hashCode => label.hashCode;
}

class WeightTier {
  static const small = WeightTier._internal('Small', '< 5 kg');
  static const medium = WeightTier._internal('Medium', '5-15 kg');
  static const large = WeightTier._internal('Large', '15-30 kg');
  static const bulk = WeightTier._internal('Bulk', '30+ kg');
  
  final String label;
  final String weightRange;
  
  const WeightTier._internal(this.label, this.weightRange);
  
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is WeightTier && other.label == label;
  }
  
  @override
  int get hashCode => label.hashCode;
}

class DeliveryRequest {
  final String id;
  final String senderName;
  final String pickupAddress;
  final String dropoffAddress;
  final int etaToPickupMinutes;
  final ParcelType parcelType;
  final WeightTier weightTier;
  final bool isFragile;
  final bool needsHelpers;
  final String? photoUrl;
  final String? specialInstructions;
  final double deliveryFee;
  final double distanceKm;
  final DateTime requestedAt;
  final double customerRating;

  double get fare => deliveryFee;

  DeliveryRequest({
    required this.id,
    required this.senderName,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.etaToPickupMinutes,
    required this.parcelType,
    required this.weightTier,
    required this.isFragile,
    required this.needsHelpers,
    this.photoUrl,
    this.specialInstructions,
    required this.deliveryFee,
    required this.distanceKm,
    required this.requestedAt,
    required this.customerRating,
  });
}