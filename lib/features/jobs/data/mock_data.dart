import '../../driver/models/driver_type.dart' hide WeightTier;
import '../../jobs/models/ride_request.dart';
import '../../jobs/models/delivery_request.dart';
import '../../earnings/models/wallet_transaction.dart';
import '../../trips/models/trip_record.dart';
import '../../../features/earnings/models/earning_record.dart';



class MockDataService {
  static final List<RideRequest> _allRideRequests = [
    RideRequest(
      id: 'r1',
      passengerName: 'Kofi Mensah',
      passengerRating: 4.7,
      pickupAddress: 'Accra Mall, Spintex Road',
      dropoffAddress: 'University of Ghana, Legon',
      etaToPickupMinutes: 4,
      seatCount: 1,
      fare: 35.00,
      distanceKm: 8.2,
      requestedAt: DateTime.now().subtract(const Duration(seconds: 12)),
    ),
    RideRequest(
      id: 'r2',
      passengerName: 'Ama Asante',
      passengerRating: 4.9,
      pickupAddress: 'Osu Oxford Street',
      dropoffAddress: 'Kotoka International Airport',
      etaToPickupMinutes: 7,
      seatCount: 1,
      fare: 52.00,
      distanceKm: 12.5,
      requestedAt: DateTime.now().subtract(const Duration(seconds: 45)),
    ),
    RideRequest(
      id: 'r3',
      passengerName: 'Kwame Boateng',
      passengerRating: 4.4,
      pickupAddress: 'Labadi Beach Hotel',
      dropoffAddress: 'A&C Mall, East Legon',
      etaToPickupMinutes: 3,
      seatCount: 2,
      fare: 28.00,
      distanceKm: 6.0,
      requestedAt: DateTime.now().subtract(const Duration(seconds: 5)),
    ),
  ];

  static final List<DeliveryRequest> _allDeliveryRequests = [
    // Small – fits okadaDelivery
    DeliveryRequest(
      id: 'd1',
      senderName: 'Efua Darko',
      pickupAddress: 'Makola Market, Central Accra',
      dropoffAddress: 'Adenta Housing Down',
      etaToPickupMinutes: 5,
      parcelType: ParcelType.document,
      weightTier: WeightTier.small,
      isFragile: false,
      needsHelpers: false,
      photoUrl: null,
      specialInstructions: 'Call recipient before arriving',
      deliveryFee: 22.00,
      distanceKm: 14.3,
      requestedAt: DateTime.now().subtract(const Duration(seconds: 20)),
      customerRating: 4.8,
    ),
    // Medium – fits okadaDelivery and aboboya
    DeliveryRequest(
      id: 'd2',
      senderName: 'Nana Brew',
      pickupAddress: 'Tema Station, Accra',
      dropoffAddress: 'Cantonments, Accra',
      etaToPickupMinutes: 8,
      parcelType: ParcelType.food,
      weightTier: WeightTier.medium,
      isFragile: true,
      needsHelpers: false,
      photoUrl: 'https://picsum.photos/seed/food/200/200',
      specialInstructions: 'Handle with care – hot food',
      deliveryFee: 38.00,
      distanceKm: 9.1,
      requestedAt: DateTime.now().subtract(const Duration(seconds: 60)),
      customerRating: 4.5,
    ),
    // Large – fits aboboya
    DeliveryRequest(
      id: 'd3',
      senderName: 'Ebo Quansah',
      pickupAddress: 'Timber Market, Accra',
      dropoffAddress: 'Spintex, Community 18',
      etaToPickupMinutes: 6,
      parcelType: ParcelType.furniture,
      weightTier: WeightTier.large,
      isFragile: false,
      needsHelpers: true,
      photoUrl: 'https://picsum.photos/seed/furniture/200/200',
      specialInstructions: '2 people needed for offloading',
      deliveryFee: 85.00,
      distanceKm: 17.8,
      requestedAt: DateTime.now().subtract(const Duration(seconds: 30)),
      customerRating: 4.2,
    ),
    // Bulk – fits miniTruck only
    DeliveryRequest(
      id: 'd4',
      senderName: 'Kojo Asiedu',
      pickupAddress: 'Ashiaman Industrial Area',
      dropoffAddress: 'Tema Port, Gate 3',
      etaToPickupMinutes: 12,
      parcelType: ParcelType.other,
      weightTier: WeightTier.bulk,
      isFragile: false,
      needsHelpers: true,
      photoUrl: 'https://picsum.photos/seed/cargo/200/200',
      specialInstructions: 'Industrial equipment – driver must verify load',
      deliveryFee: 250.00,
      distanceKm: 24.6,
      requestedAt: DateTime.now().subtract(const Duration(seconds: 90)),
      customerRating: 4.9,
    ),
    // Another medium
    DeliveryRequest(
      id: 'd5',
      senderName: 'Gifty Agyemang',
      pickupAddress: 'West Hills Mall, Weija',
      dropoffAddress: 'Dansoman, Accra',
      etaToPickupMinutes: 4,
      parcelType: ParcelType.electronics,
      weightTier: WeightTier.medium,
      isFragile: true,
      needsHelpers: false,
      photoUrl: 'https://picsum.photos/seed/electronics/200/200',
      specialInstructions: 'Fragile electronics – do not tilt',
      deliveryFee: 45.00,
      distanceKm: 10.2,
      requestedAt: DateTime.now().subtract(const Duration(seconds: 15)),
      customerRating: 4.7,
    ),
  ];

  /// Returns only the requests the driver is allowed to see
  static List<RideRequest> getRideRequestsFor(DriverType type) {
    if (!type.isRide) return [];
    return List.from(_allRideRequests);
  }

  static List<DeliveryRequest> getDeliveryRequestsFor(DriverType type) {
    if (!type.isDelivery) return [];
    final allowed = type.allowedWeightTiers;
    return _allDeliveryRequests
        .where((r) => allowed.contains(r.weightTier))
        .toList();
  }

  static List<TripRecord> getMockTripHistory() {
    final now = DateTime.now();
    return [
      TripRecord(
        id: 't1',
        driverType: DriverType.okadaHailing,
        customerName: 'Kofi Mensah',
        pickupAddress: 'Accra Mall',
        dropoffAddress: 'Legon',
        fare: 35.00,
        distanceKm: 8.2,
        completedAt: now.subtract(const Duration(hours: 2)),
        driverRating: 5.0,
        isDelivery: false,
      ),
      TripRecord(
        id: 't2',
        driverType: DriverType.okadaDelivery,
        customerName: 'Efua Darko',
        pickupAddress: 'Makola Market',
        dropoffAddress: 'Adenta',
        fare: 22.00,
        distanceKm: 14.3,
        completedAt: now.subtract(const Duration(hours: 5)),
        driverRating: 4.5,
        isDelivery: true,
      ),
      TripRecord(
        id: 't3',
        driverType: DriverType.okadaHailing,
        customerName: 'Ama Asante',
        pickupAddress: 'Osu Oxford St',
        dropoffAddress: 'Airport',
        fare: 52.00,
        distanceKm: 12.5,
        completedAt: now.subtract(const Duration(days: 1, hours: 1)),
        driverRating: 5.0,
        isDelivery: false,
      ),
      TripRecord(
        id: 't4',
        driverType: DriverType.okadaDelivery,
        customerName: 'Nana Brew',
        pickupAddress: 'Tema Station',
        dropoffAddress: 'Cantonments',
        fare: 38.00,
        distanceKm: 9.1,
        completedAt: now.subtract(const Duration(days: 1, hours: 4)),
        driverRating: 4.0,
        isDelivery: true,
      ),
      TripRecord(
        id: 't5',
        driverType: DriverType.okadaHailing,
        customerName: 'Kwame Boateng',
        pickupAddress: 'Labadi Beach',
        dropoffAddress: 'A&C Mall',
        fare: 28.00,
        distanceKm: 6.0,
        completedAt: now.subtract(const Duration(days: 2)),
        driverRating: 4.8,
        isDelivery: false,
      ),
      TripRecord(
        id: 't6',
        driverType: DriverType.okadaDelivery,
        customerName: 'Gifty Agyemang',
        pickupAddress: 'West Hills Mall',
        dropoffAddress: 'Dansoman',
        fare: 45.00,
        distanceKm: 10.2,
        completedAt: now.subtract(const Duration(days: 2, hours: 3)),
        driverRating: 5.0,
        isDelivery: true,
      ),
      TripRecord(
        id: 't7',
        driverType: DriverType.okadaHailing,
        customerName: 'Yaw Frimpong',
        pickupAddress: 'Accra Central',
        dropoffAddress: 'East Legon',
        fare: 40.00,
        distanceKm: 11.3,
        completedAt: now.subtract(const Duration(days: 3)),
        driverRating: 4.7,
        isDelivery: false,
      ),
    ];
  }

  static List<EarningsRecord> getMockEarnings() {
    final now = DateTime.now();
    return List.generate(7, (i) {
      final date = now.subtract(Duration(days: i));
      final trips = 5 + (i % 4);
      final gross = (trips * 38.0) + (i * 7.5);
      final fee = gross * 0.15;
      return EarningsRecord(
        date: date,
        netEarnings: gross - fee,
        totalEarnings: gross,
        platformFee: fee,
        totalTrips: trips,
      );
    });
  }

  static List<WalletTransaction> getMockTransactions() {
    final now = DateTime.now();
    return [
      WalletTransaction(
        id: 'w1',
        description: 'Trip earnings – Kofi Mensah',
        amount: 35.00,
        isCredit: true,
        timestamp: now.subtract(const Duration(hours: 2)),
        status: 'completed',
      ),
      WalletTransaction(
        id: 'w2',
        description: 'Delivery earnings – Efua Darko',
        amount: 22.00,
        isCredit: true,
        timestamp: now.subtract(const Duration(hours: 5)),
        status: 'completed',
      ),
      WalletTransaction(
        id: 'w3',
        description: 'Withdrawal to MTN MoMo',
        amount: 100.00,
        isCredit: false,
        timestamp: now.subtract(const Duration(days: 1)),
        status: 'completed',
      ),
      WalletTransaction(
        id: 'w4',
        description: 'Trip earnings – Ama Asante',
        amount: 52.00,
        isCredit: true,
        timestamp: now.subtract(const Duration(days: 1, hours: 1)),
        status: 'completed',
      ),
      WalletTransaction(
        id: 'w5',
        description: 'Withdrawal to Vodafone Cash',
        amount: 50.00,
        isCredit: false,
        timestamp: now.subtract(const Duration(days: 2)),
        status: 'pending',
      ),
      WalletTransaction(
        id: 'w6',
        description: 'Bonus – Weekend incentive',
        amount: 15.00,
        isCredit: true,
        timestamp: now.subtract(const Duration(days: 2, hours: 6)),
        status: 'completed',
      ),
    ];
  }
}