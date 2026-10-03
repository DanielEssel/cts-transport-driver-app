// lib/features/driver/presentation/widgets/requests_section.dart

import 'dart:async';
import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:cts_transport_driver_app/core/constants/app_colors.dart';
import 'package:cts_transport_driver_app/core/constants/design_constants.dart';
import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart';
import 'package:cts_transport_driver_app/app/app_routes.dart';
import 'gas_dispatch_policy.dart';

// ─────────────────────────────────────────────────────────────────────────────
// REQUEST TYPE ENUM
// ─────────────────────────────────────────────────────────────────────────────

enum RequestType { ride, delivery, gas }

// ─────────────────────────────────────────────────────────────────────────────
// UNIFIED REQUEST MODEL
// ─────────────────────────────────────────────────────────────────────────────

class AvailableRequest {
  final String id;
  final String passengerId;
  final RequestType type;
  final String status;
  final String pickupAddress;
  final String dropoffAddress;
  final GeoPoint pickupLocation;
  final GeoPoint dropoffLocation;
  final double fare;
  final DateTime createdAt;
  final String collection; // which Firestore collection it came from

  // Ride-only
  final int passengerCount;

  // Delivery-only
  final String? packageDescription;
  final String? weightTier;
  final String? recipientName;
  final String? recipientPhone;
  final String? photoUrl;

  // Gas-only
  // Gas-only
  final String? refillType;
  final String? cylinderSize;
  final int? cylinderQuantity;
  final double? deliveryFee;

  const AvailableRequest({
    required this.id,
    required this.passengerId,
    required this.type,
    required this.status,
    this.refillType,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.pickupLocation,
    required this.dropoffLocation,
    required this.fare,
    required this.createdAt,
    required this.collection,
    this.passengerCount = 1,
    this.packageDescription,
    this.weightTier,
    this.recipientName,
    this.recipientPhone,
    this.photoUrl,
    this.cylinderSize,
    this.cylinderQuantity,
    this.deliveryFee,
  });

  // ── Trip (ride) from 'trips' collection ──
  factory AvailableRequest.fromTripFirestore(
      Map<String, dynamic> data, String id) {
    return AvailableRequest(
      id: id,
      passengerId: data['passengerId'] as String? ?? '',
      type: RequestType.ride,
      status: data['status'] as String? ?? 'searching',
      pickupAddress: data['pickupAddress'] as String? ?? 'Unknown pickup',
      dropoffAddress: data['dropoffAddress'] as String? ?? 'Unknown dropoff',
      pickupLocation:
          data['pickupLocation'] as GeoPoint? ?? const GeoPoint(0, 0),
      dropoffLocation:
          data['dropoffLocation'] as GeoPoint? ?? const GeoPoint(0, 0),
      fare: (data['estimatedFare'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      collection: 'trips',
      passengerCount: data['passengerCount'] as int? ?? 1,
    );
  }

// ── Delivery from 'deliveries' collection ──
  factory AvailableRequest.fromDeliveryFirestore(
      Map<String, dynamic> data, String id) {
    return AvailableRequest(
      id: id,
      passengerId: data['passengerId'] as String? ?? '',
      type: RequestType.delivery,
      status: data['status'] as String? ?? 'pending',
      pickupAddress: data['pickupAddress'] as String? ?? 'Unknown pickup',
      dropoffAddress: data['dropoffAddress'] as String? ?? 'Unknown dropoff',
      pickupLocation:
          data['pickupLocation'] as GeoPoint? ?? const GeoPoint(0, 0),
      dropoffLocation:
          data['dropoffLocation'] as GeoPoint? ?? const GeoPoint(0, 0),
      fare: (data['estimatedFare'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      collection: 'deliveries',
      packageDescription: data['parcelType'] as String?,
      weightTier: data['weightTier'] as String?,
      recipientName: data['receiverName'] as String?,
      recipientPhone: data['receiverPhone'] as String?,
      photoUrl: data['photoUrl'] as String?,
    );
  }

  // ── Gas order from 'gas_orders' collection ──
  factory AvailableRequest.fromGasFirestore(
      Map<String, dynamic> data, String id) {
    return AvailableRequest(
      id: id,
      passengerId: data['passengerId'] as String? ?? '',
      type: RequestType.gas,
      status: data['status'] as String? ?? 'pendingApproval',
      pickupAddress: data['pickupAddress'] as String? ?? 'Unknown',
      dropoffAddress: data['deliveryAddress'] as String? ?? 'Unknown',
      pickupLocation:
          data['pickupLocation'] as GeoPoint? ?? const GeoPoint(0, 0),
      dropoffLocation:
          data['deliveryLocation'] as GeoPoint? ?? const GeoPoint(0, 0),
      fare: (data['deliveryFee'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      collection: 'gas_orders',
      refillType: data['refillType'] as String?,
      cylinderSize: data['cylinderSize'] as String?,
      cylinderQuantity: data['quantity'] as int? ?? 1,
      deliveryFee: (data['deliveryFee'] as num?)?.toDouble(),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DISPATCH RADIUS
// ─────────────────────────────────────────────────────────────────────────────

const double _dispatchRadiusKm = 10.0;

/// Returns true when the request pickup is within the driver's dispatch radius.
///
/// This intentionally uses the driver's currentLocation and the request's
/// pickupLocation. Firestore does not perform native radius queries, so the
/// pending requests are fetched first and filtered client-side.
bool _isWithinDispatchRadius(
  GeoPoint? driverLocation,
  GeoPoint requestLocation,
) {
  if (driverLocation == null) return false;

  // Guard against missing/invalid Firestore coordinates.
  if (requestLocation.latitude == 0.0 && requestLocation.longitude == 0.0) {
    return false;
  }

  const earthRadiusKm = 6371.0;

  final dLat = _degreesToRadians(
    requestLocation.latitude - driverLocation.latitude,
  );
  final dLon = _degreesToRadians(
    requestLocation.longitude - driverLocation.longitude,
  );

  final lat1 = _degreesToRadians(driverLocation.latitude);
  final lat2 = _degreesToRadians(requestLocation.latitude);

  final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
      math.sin(dLon / 2) * math.sin(dLon / 2) * math.cos(lat1) * math.cos(lat2);

  final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  final distanceKm = earthRadiusKm * c;

  return distanceKm <= _dispatchRadiusKm;
}

double _degreesToRadians(double degrees) => degrees * math.pi / 180.0;

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────

/// Streams pending rides from 'trips' collection
final _pendingRidesProvider =
    StreamProvider.family<List<AvailableRequest>, DriverProfile>((ref, driver) {
  if (!driver.isRide) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('trips')
      .where('status', isEqualTo: 'searching')
      .where('serviceType', isEqualTo: driver.serviceType)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map(
        (snap) => snap.docs
            .where((d) => d.data()['driverId'] == null)
            .map((d) => AvailableRequest.fromTripFirestore(d.data(), d.id))
            .where(
              (request) => _isWithinDispatchRadius(
                driver.currentLocation,
                request.pickupLocation,
              ),
            )
            .toList(),
      );
});

/// Streams pending deliveries from 'deliveries' collection
final _pendingDeliveriesProvider =
    StreamProvider.family<List<AvailableRequest>, DriverProfile>((ref, driver) {
  if (!driver.isDelivery) return Stream.value([]);

  Query<Map<String, dynamic>> query = FirebaseFirestore.instance
      .collection('deliveries')
      .where('status', isEqualTo: 'pending')
      .where('driverId', isNull: true)
      .orderBy('createdAt', descending: true)
      .limit(20);

  // Filter by weight tier if driver has restrictions
  final tiers = driver.allowedWeightTiers.map((t) => t.label).toList();
  if (tiers.isNotEmpty) {
    query = query.where('weightTier', whereIn: tiers);
  }

  return query.snapshots().map(
        (snap) => snap.docs
            .map((d) => AvailableRequest.fromDeliveryFirestore(d.data(), d.id))
            .where(
              (request) => _isWithinDispatchRadius(
                driver.currentLocation,
                request.pickupLocation,
              ),
            )
            .toList(),
      );
});

/// Streams pending gas orders from 'gas_orders' collection
/// Streams pending gas orders from 'gas_orders' collection
final _pendingGasProvider =
    StreamProvider.family<List<AvailableRequest>, DriverProfile>((ref, driver) {
  if (!driver.isDelivery) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('gas_orders')
      .where('status', isEqualTo: 'pendingApproval')
      .where('driverId', isNull: true)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map(
        (snap) => snap.docs
            .map((d) => AvailableRequest.fromGasFirestore(d.data(), d.id))
            .where(
              (request) =>
                  canDriverHandleGasOrder(
                    driver.vehicleType,
                    request.refillType,
                  ) &&
                  _isWithinDispatchRadius(
                    driver.currentLocation,
                    request.pickupLocation,
                  ),
            )
            .toList(),
      );
});

/// Combines all three into one sorted list
final pendingRequestsProvider =
    Provider.family<AsyncValue<List<AvailableRequest>>, DriverProfile>(
        (ref, driver) {
  final ridesAsync = ref.watch(_pendingRidesProvider(driver));
  final deliveriesAsync = ref.watch(_pendingDeliveriesProvider(driver));
  final gasAsync = ref.watch(_pendingGasProvider(driver));

  if (ridesAsync.isLoading || deliveriesAsync.isLoading || gasAsync.isLoading) {
    return const AsyncValue.loading();
  }

  if (ridesAsync.hasError) {
    return AsyncValue.error(ridesAsync.error!, ridesAsync.stackTrace!);
  }

  final rides = ridesAsync.value ?? [];
  final deliveries = deliveriesAsync.value ?? [];
  final gas = gasAsync.value ?? [];

  final combined = [...rides, ...deliveries, ...gas]
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

  return AsyncValue.data(combined);
});

// ─────────────────────────────────────────────────────────────────────────────
// REQUESTS SECTION WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class RequestsSection extends ConsumerWidget {
  const RequestsSection({
    super.key,
    required this.driver,
    required this.isOnline,
    required this.onGoOnline,
  });

  final DriverProfile driver;
  final bool isOnline;
  final VoidCallback onGoOnline;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text(
              'Available Requests',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Spacer(),
            if (isOnline) _LiveDot(),
          ],
        ),
        const SizedBox(height: SpacingConstants.md),
        if (!isOnline)
          _OfflineCard(onGoOnline: onGoOnline)
        else
          _LiveRequestsList(driver: driver),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE REQUESTS LIST
// ─────────────────────────────────────────────────────────────────────────────

class _LiveRequestsList extends ConsumerWidget {
  const _LiveRequestsList({required this.driver});
  final DriverProfile driver;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(pendingRequestsProvider(driver));

    return requestsAsync.when(
      loading: () => const _SearchingState(),
      error: (e, _) => _EmptyState(
        icon: Icons.cloud_off_rounded,
        message: 'Could not load requests.\nCheck your connection.',
        iconColor: AppColors.errorColor,
        action: TextButton(
          onPressed: () => ref.invalidate(_pendingRidesProvider(driver)),
          child: const Text('Retry'),
        ),
      ),
      data: (requests) => requests.isEmpty
          ? const _SearchingState()
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              separatorBuilder: (_, __) =>
                  const SizedBox(height: SpacingConstants.sm),
              itemBuilder: (_, i) => _RequestCard(
                request: requests[i],
                driverUid: driver.uid,
              ),
            ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// REQUEST CARD
// ─────────────────────────────────────────────────────────────────────────────

class _RequestCard extends StatefulWidget {
  const _RequestCard({
    required this.request,
    required this.driverUid,
  });
  final AvailableRequest request;
  final String driverUid;

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard>
    with SingleTickerProviderStateMixin {
  bool _isAccepting = false;

  static const _expectedStatus = {
    'trips': 'searching',
    'deliveries': 'pending',
    'gas_orders': 'pendingApproval',
  };

  static const _acceptedStatus = {
    'trips': 'tripAccepted',
    'deliveries': 'driverAssigned',
    'gas_orders': 'driverAssigned',
  };

  void _showParcelPhoto(String photoUrl) {
    showDialog<void>(
      context: context,
      barrierColor: Colors.black87,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Center(
                child: InteractiveViewer(
                  minScale: 0.8,
                  maxScale: 4.0,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Image.network(
                      photoUrl,
                      fit: BoxFit.contain,
                      loadingBuilder: (context, child, progress) {
                        if (progress == null) return child;

                        return const SizedBox(
                          width: 80,
                          height: 80,
                          child: Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, __, ___) {
                        return Container(
                          width: 240,
                          height: 240,
                          decoration: BoxDecoration(
                            color: Colors.white10,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: const Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.broken_image_outlined,
                                color: Colors.white70,
                                size: 42,
                              ),
                              SizedBox(height: 12),
                              Text(
                                'Unable to load parcel photo',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Material(
                  color: Colors.black54,
                  shape: const CircleBorder(),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: () => Navigator.of(context).pop(),
                    child: const Padding(
                      padding: EdgeInsets.all(10),
                      child: Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                        size: 22,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _acceptRequest() async {
    HapticFeedback.mediumImpact();
    setState(() => _isAccepting = true);
    final nav = Navigator.of(context, rootNavigator: true);

    try {
      final req = widget.request;

      // ── Trips: existing client-side transaction ───────────────────────
      if (req.collection == 'trips') {
        final db = FirebaseFirestore.instance;
        final driverSnap =
            await db.collection('drivers').doc(widget.driverUid).get();
        final d = driverSnap.data() ?? {};
        final driverName = d['displayName'] as String? ?? 'Your driver';
        final driverPhone = d['phone'] as String? ?? '';
        final driverRating = (d['rating'] as num?)?.toDouble() ?? 5.0;
        final driverPlate = d['vehiclePlate'] as String? ?? '';

        await db.runTransaction((tx) async {
          final tripRef = db.collection('trips').doc(req.id);
          final snap = await tx.get(tripRef);

          if (!snap.exists) {
            throw Exception('Trip no longer available');
          }

          final tripData = snap.data()!;
          final currentStatus = tripData['status'] as String? ?? '';

          if (currentStatus != 'searching') {
            throw Exception('This ride was just taken by another driver');
          }

          if (tripData['driverId'] != null) {
            throw Exception('This ride was just taken by another driver');
          }

          tx.update(tripRef, {
            'driverId': widget.driverUid,
            'driverName': driverName,
            'driverPhone': driverPhone,
            'driverRating': driverRating,
            'driverPlate': driverPlate,
            'status': 'tripAccepted',
            'acceptedAt': FieldValue.serverTimestamp(),
          });
        });

        await db.collection('drivers').doc(widget.driverUid).update({
          'isAvailable': false,
          'currentTripId': req.id,
          'currentTripType': req.collection,
        });

        _navigateToActiveScreenWithNav(nav);
        return;
      }

      // ── Gas: server-authoritative Cloud Function ───────────────────────
      if (req.collection == 'gas_orders') {
        final callable = FirebaseFunctions.instanceFor(region: 'europe-west2')
            .httpsCallable('acceptGasOrder');

        final result = await callable.call({
          'orderId': req.id,
        });

        final data = Map<String, dynamic>.from(
          result.data as Map,
        );

        if (data['success'] != true) {
          final reason = data['reason'] as String? ?? 'unknown';

          final message = switch (reason) {
            'order_not_found' => 'This gas order is no longer available.',
            'order_unavailable' => 'This gas order is no longer available.',
            'order_already_assigned' =>
              'This gas order was just accepted by another driver.',
            'driver_not_found' => 'Your driver profile could not be found.',
            'driver_not_eligible' =>
              'You are not currently eligible to accept gas orders.',
            'vehicle_not_eligible' =>
              'Your vehicle cannot handle this type of gas order.',
            _ => 'This gas order could not be accepted.',
          };

          throw Exception(message);
        }

        _navigateToActiveScreenWithNav(nav);
        return;
      }

      // ── Deliveries: EXISTING acceptance logic — unchanged ─────────────
      final db = FirebaseFirestore.instance;
      final driverSnap =
          await db.collection('drivers').doc(widget.driverUid).get();
      final d = driverSnap.data() ?? {};
      final driverName = d['displayName'] as String? ?? 'Your driver';
      final driverPhone = d['phoneNumber'] as String? ?? '';
      final driverRating = (d['rating'] as num?)?.toDouble() ?? 5.0;

      await db.runTransaction((tx) async {
        final docRef = db.collection(req.collection).doc(req.id);
        final snap = await tx.get(docRef);

        if (!snap.exists) {
          throw Exception('Request no longer available');
        }

        final data = snap.data()!;

        if (data['driverId'] != null) {
          throw Exception('Request already taken by another driver');
        }

        final currentStatus = data['status'] as String? ?? '';
        final expected = _expectedStatus[req.collection] ?? 'pending';
        final accepted = _acceptedStatus[req.collection] ?? 'driverAssigned';

        if (currentStatus != expected) {
          throw Exception('Request is no longer available');
        }

        tx.update(docRef, {
          'driverId': widget.driverUid,
          'driverName': driverName,
          'driverPhone': driverPhone,
          'driverRating': driverRating,
          'status': accepted,
          'acceptedAt': FieldValue.serverTimestamp(),
        });
      });

      // Mark driver busy — powers the resume banner + stops new dispatches.
      db.collection('drivers').doc(widget.driverUid).update({
        'isAvailable': false,
        'currentTripId': req.id,
        'currentTripType': req.collection,
      }).catchError((_) {});

      _navigateToActiveScreenWithNav(nav);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        final message = switch (e.code) {
          'unauthenticated' =>
            'Please sign in again before accepting this request.',
          'invalid-argument' => 'Invalid gas order request.',
          'internal' =>
            'Unable to accept the gas order right now. Please try again.',
          _ => e.message ?? 'Failed to accept request',
        };

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e.toString().replaceFirst('Exception: ', ''),
            ),
            backgroundColor: AppColors.errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isAccepting = false);
      }
    }
  }

  void _navigateToActiveScreenWithNav(NavigatorState nav) {
    final req = widget.request;
    switch (req.type) {
      case RequestType.ride:
        nav.pushNamed(AppRoutes.activeTrip, arguments: {'tripId': req.id});
        break;
      case RequestType.delivery:
        nav.pushNamed(AppRoutes.activeDelivery,
            arguments: {'deliveryId': req.id});
        break;
      case RequestType.gas:
        nav.pushNamed(AppRoutes.activeGas, arguments: {'orderId': req.id});
        break;
    }
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final req = widget.request;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(SpacingConstants.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: type badge + fare ──
            Row(
              children: [
                _TypeBadge(type: req.type),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      'GH₵ ${req.fare.toStringAsFixed(2)}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 18,
                        color: AppColors.primaryColor,
                      ),
                    ),
                    Text(
                      _timeAgo(req.createdAt),
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textSecondaryColor,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: SpacingConstants.sm),
            const Divider(height: 1),
            const SizedBox(height: SpacingConstants.sm),

            // ── Locations ──
            _LocationRow(
              icon: Icons.radio_button_checked,
              iconColor: Colors.green,
              label: req.type == RequestType.gas ? 'Station' : 'Pickup',
              address: req.pickupAddress,
            ),
            const SizedBox(height: 8),
            _LocationRow(
              icon: Icons.location_on_rounded,
              iconColor: AppColors.errorColor,
              label: 'Dropoff',
              address: req.dropoffAddress,
            ),

            if (req.type == RequestType.delivery &&
                req.photoUrl != null &&
                req.photoUrl!.trim().isNotEmpty) ...[
              const SizedBox(height: SpacingConstants.sm),
              GestureDetector(
                onTap: () => _showParcelPhoto(req.photoUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 96,
                    width: double.infinity,
                    color: AppColors.backgroundColor,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.network(
                          req.photoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Center(
                            child: Icon(
                              Icons.broken_image_outlined,
                              size: 32,
                              color: AppColors.textSecondaryColor,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.zoom_in_rounded,
                                  size: 14,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'View parcel',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],

            // ── Type-specific extras ──
            if (req.type == RequestType.delivery &&
                req.packageDescription != null) ...[
              const SizedBox(height: SpacingConstants.sm),
              const Divider(height: 1),
              const SizedBox(height: SpacingConstants.sm),
              _DeliveryExtras(request: req),
            ],

            if (req.type == RequestType.gas) ...[
              const SizedBox(height: SpacingConstants.sm),
              const Divider(height: 1),
              const SizedBox(height: SpacingConstants.sm),
              _GasExtras(request: req),
            ],

            if (req.type == RequestType.ride && req.passengerCount > 1) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person_rounded,
                      size: 14, color: AppColors.textSecondaryColor),
                  const SizedBox(width: 4),
                  Text(
                    '${req.passengerCount} passengers',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondaryColor,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: SpacingConstants.md),

            // ── Accept button ──
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isAccepting ? null : _acceptRequest,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryColor,
                  disabledBackgroundColor:
                      AppColors.primaryColor.withValues(alpha: 0.5),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _isAccepting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Accept ${_requestLabel(req.type)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 15,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _requestLabel(RequestType type) => switch (type) {
        RequestType.ride => 'Ride',
        RequestType.delivery => 'Delivery',
        RequestType.gas => 'Gas Order',
      };

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inSeconds < 60) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    return '${diff.inHours}h ago';
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DELIVERY EXTRAS
// ─────────────────────────────────────────────────────────────────────────────

class _DeliveryExtras extends StatelessWidget {
  const _DeliveryExtras({required this.request});

  final AvailableRequest request;

  @override
  Widget build(BuildContext context) {
    final hasParcel = request.packageDescription != null &&
        request.packageDescription!.trim().isNotEmpty;

    final hasWeight =
        request.weightTier != null && request.weightTier!.trim().isNotEmpty;

    final hasRecipient = request.recipientName != null &&
        request.recipientName!.trim().isNotEmpty;

    final hasPhone = request.recipientPhone != null &&
        request.recipientPhone!.trim().isNotEmpty;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.borderColor.withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Parcel ──
          const Row(
            children: [
              Icon(
                Icons.inventory_2_rounded,
                size: 16,
                color: AppColors.textSecondaryColor,
              ),
              SizedBox(width: 6),
              Text(
                'Parcel',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimaryColor,
                ),
              ),
            ],
          ),

          const SizedBox(height: 8),

          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  hasParcel ? request.packageDescription!.trim() : 'Parcel',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimaryColor,
                  ),
                ),
              ),
              if (hasWeight)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    request.weightTier!.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
            ],
          ),

          // ── Receiver ──
          if (hasRecipient || hasPhone) ...[
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(
                  Icons.person_rounded,
                  size: 16,
                  color: AppColors.textSecondaryColor,
                ),
                SizedBox(width: 6),
                Text(
                  'Receiver',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            if (hasRecipient)
              Text(
                request.recipientName!.trim(),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textPrimaryColor,
                ),
              ),
            if (hasPhone)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  request.recipientPhone!.trim(),
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondaryColor,
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GAS EXTRAS
// ─────────────────────────────────────────────────────────────────────────────

class _GasExtras extends StatelessWidget {
  const _GasExtras({required this.request});
  final AvailableRequest request;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          const Icon(Icons.local_fire_department_rounded,
              size: 15, color: Colors.orange),
          const SizedBox(width: 6),
          Text(
            '${request.cylinderSize ?? 'Gas cylinder'}'
            ' × ${request.cylinderQuantity ?? 1}',
            style: const TextStyle(
              fontSize: 12,
              color: AppColors.textSecondaryColor,
            ),
          ),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Text(
              'GAS ORDER',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: Colors.orange,
              ),
            ),
          ),
        ],
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// OFFLINE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _OfflineCard extends StatelessWidget {
  const _OfflineCard({required this.onGoOnline});
  final VoidCallback onGoOnline;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SpacingConstants.lg),
        decoration: BoxDecoration(
          color: AppColors.borderColor.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            const Icon(Icons.wifi_off_rounded,
                size: 40, color: AppColors.textSecondaryColor),
            const SizedBox(height: SpacingConstants.sm),
            const Text(
              "You're offline",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            const SizedBox(height: 4),
            const Text(
              'Go online to start receiving requests.',
              textAlign: TextAlign.center,
              style:
                  TextStyle(color: AppColors.textSecondaryColor, fontSize: 13),
            ),
            const SizedBox(height: SpacingConstants.md),
            FilledButton.icon(
              onPressed: onGoOnline,
              icon: const Icon(Icons.power_settings_new_rounded),
              label: const Text('Go Online'),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SEARCHING STATE (animated pulse)
// ─────────────────────────────────────────────────────────────────────────────

class _SearchingState extends StatefulWidget {
  const _SearchingState();

  @override
  State<_SearchingState> createState() => _SearchingStateState();
}

class _SearchingStateState extends State<_SearchingState>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  late final Animation<double> _anim =
      Tween<double>(begin: 0.4, end: 1.0).animate(_controller);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SpacingConstants.xl),
        decoration: BoxDecoration(
          color: AppColors.borderColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            FadeTransition(
              opacity: _anim,
              child: const Icon(Icons.radar_rounded,
                  size: 48, color: AppColors.primaryColor),
            ),
            const SizedBox(height: SpacingConstants.sm),
            const Text(
              'Searching for requests nearby...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.textSecondaryColor,
                fontSize: 13,
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY / ERROR STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.message,
    required this.iconColor,
    this.action,
  });

  final IconData icon;
  final String message;
  final Color iconColor;
  final Widget? action;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(SpacingConstants.xl),
        decoration: BoxDecoration(
          color: AppColors.borderColor.withValues(alpha: 0.2),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(icon, size: 40, color: iconColor),
            const SizedBox(height: SpacingConstants.sm),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.textSecondaryColor,
                fontSize: 13,
              ),
            ),
            if (action != null) ...[
              const SizedBox(height: SpacingConstants.sm),
              action!,
            ],
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// SUB-WIDGETS
// ─────────────────────────────────────────────────────────────────────────────

class _LiveDot extends StatefulWidget {
  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 1),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FadeTransition(
            opacity: _c,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 4),
          const Text(
            'LIVE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: Colors.green,
              letterSpacing: 1,
            ),
          ),
        ],
      );
}

class _TypeBadge extends StatelessWidget {
  const _TypeBadge({required this.type});
  final RequestType type;

  @override
  Widget build(BuildContext context) {
    final Color color;
    final IconData icon;
    final String label;

    switch (type) {
      case RequestType.delivery:
        color = Colors.orange;
        icon = Icons.delivery_dining_rounded;
        label = 'Delivery';
        break;
      case RequestType.gas:
        color = const Color(0xFFD97706);
        icon = Icons.local_fire_department_rounded;
        label = 'Gas Order';
        break;
      case RequestType.ride:
        color = AppColors.primaryColor;
        icon = Icons.directions_car_rounded;
        label = 'Ride';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocationRow extends StatelessWidget {
  const _LocationRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.address,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String address;

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: iconColor),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 10,
                    color: AppColors.textSecondaryColor,
                  ),
                ),
                Text(
                  address,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
