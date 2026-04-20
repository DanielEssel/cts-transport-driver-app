// ─── Driver type ──────────────────────────────────────────────────────────────
// Set at signup vehicle setup. Never changed after that.
// Controls which requests appear on the driver home screen.

enum DriverType {
  okadaHailing,  // motorbike — passenger rides only
  okadaDelivery, // motorbike — small parcels only (0–5 kg)
  aboboya,       // tricycle  — medium + large (5–100 kg)
  miniTruck;    // truck     — bulk only (100 kg+)

  String get displayName {
    switch (this) {
      case DriverType.okadaHailing:
        return 'Okada – Ride Hailing';
      case DriverType.okadaDelivery:
        return 'Okada – Delivery';
      case DriverType.aboboya:
        return 'Aboboya (Tricycle)';
      case DriverType.miniTruck:
        return 'Mini Truck';
    }
  }

  bool get isDelivery =>
      this == DriverType.okadaDelivery ||
      this == DriverType.aboboya ||
      this == DriverType.miniTruck;

  bool get isRide => this == DriverType.okadaHailing;

  List<WeightTier> get allowedWeightTiers {
    switch (this) {
      case DriverType.okadaHailing:
        return [];
      case DriverType.okadaDelivery:
        return [WeightTier.small, WeightTier.medium];
      case DriverType.aboboya:
        return [WeightTier.medium, WeightTier.large];
      case DriverType.miniTruck:
        return [WeightTier.large, WeightTier.bulk];
    }
  }

  String get vehicleIcon {
    switch (this) {
      case DriverType.okadaHailing:
      case DriverType.okadaDelivery:
        return '🏍️';
      case DriverType.aboboya:
        return '🛺';
      case DriverType.miniTruck:
        return '🚚';
    }
  }
}

enum WeightTier {
  small,
  medium,
  large,
  bulk;

  String get label {
    switch (this) {
      case WeightTier.small:
        return 'Small';
      case WeightTier.medium:
        return 'Medium';
      case WeightTier.large:
        return 'Large';
      case WeightTier.bulk:
        return 'Bulk';
    }
  }

  String get weightRange {
    switch (this) {
      case WeightTier.small:
        return '< 5 kg';
      case WeightTier.medium:
        return '5 – 20 kg';
      case WeightTier.large:
        return '20 – 100 kg';
      case WeightTier.bulk:
        return '100 kg+';
    }
  }
}

// ─── Rider type ───────────────────────────────────────────────────────────────
// Set at role selection. Controls what the rider home screen shows.
enum RiderType {
  hailing,  // books rides (taxi, okada)
  delivery, // sends parcels
}

extension RiderTypeX on RiderType {
  String get label => switch (this) {
    RiderType.hailing  => 'Ride Hailing',
    RiderType.delivery => 'Delivery',
  };

  bool get isHailing  => this == RiderType.hailing;
  bool get isDelivery => this == RiderType.delivery;
}


extension DriverTypeX on DriverType {
  String get label => switch (this) {
    DriverType.okadaHailing  => 'Okada — Hailing',
    DriverType.okadaDelivery => 'Okada — Delivery',
    DriverType.aboboya       => 'Aboboya (Tricycle)',
    DriverType.miniTruck     => 'Mini Truck',
  };

  String get vehicleLabel => switch (this) {
    DriverType.okadaHailing  => 'Motorbike',
    DriverType.okadaDelivery => 'Motorbike',
    DriverType.aboboya       => 'Tricycle',
    DriverType.miniTruck     => 'Mini Truck',
  };

  bool get isHailing  => this == DriverType.okadaHailing;
  bool get isDelivery => !isHailing;

  // Which weight tiers this driver can accept
  List<String> get allowedWeightTiers => switch (this) {
    DriverType.okadaDelivery => ['Small'],
    DriverType.aboboya       => ['Medium', 'Large'],
    DriverType.miniTruck     => ['Bulk'],
    _                        => [], // okadaHailing — no delivery
  };
}