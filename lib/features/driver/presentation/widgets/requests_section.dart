// lib/features/driver/presentation/widgets/requests_section.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:equatable/equatable.dart';
import 'package:cts_transport_driver_app/core/constants/app_colors.dart';
import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart';
import 'package:cts_transport_driver_app/app/app_routes.dart';
import 'package:cts_transport_driver_app/app/app_theme.dart';
import 'dispatch_eligibility.dart';

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
  final String? serviceType; // taxi / okada / pragyia — display only

  // Delivery-only
  final String? packageDescription;
  final String? weightTier;
  final String? bookedVehicle; // 'Okada' / 'Aboboya' / 'Mini Truck'
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
    this.serviceType,
    this.packageDescription,
    this.weightTier,
    this.bookedVehicle,
    this.recipientName,
    this.recipientPhone,
    this.photoUrl,
    this.cylinderSize,
    this.cylinderQuantity,
    this.deliveryFee,
  });

  /// What dispatch eligibility reads from this request.
  DispatchJob get dispatchJob => DispatchJob(
        service: switch (type) {
          RequestType.ride => DispatchService.ride,
          RequestType.delivery => DispatchService.delivery,
          RequestType.gas => DispatchService.gas,
        },
        serviceType: serviceType,
        bookedVehicle: bookedVehicle,
        weightTier: weightTier,
        refillType: refillType,
        // Gas: the customer's location, as dispatch uses it.
        point: type == RequestType.gas && validPoint(dropoffLocation)
            ? dropoffLocation
            : pickupLocation,
      );

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
      serviceType: data['serviceType'] as String?,
    );
  }

  // ── Delivery from 'delivery_offers' (functions/order_offers.js) ──
  // What an unassigned driver may see: area labels, points rounded to about
  // 1 km, the parcel and the booked fare. The exact addresses, the receiver
  // and the photo are on the order, which the driver can read once it is
  // theirs (the active delivery screen).
  factory AvailableRequest.fromDeliveryOffer(
      Map<String, dynamic> data, String id) {
    return AvailableRequest(
      id: id,
      passengerId: '',
      type: RequestType.delivery,
      status: 'pending',
      pickupAddress: _offerArea(data['pickupArea']),
      dropoffAddress: _offerArea(data['dropoffArea']),
      pickupLocation: data['pickupPoint'] as GeoPoint? ?? const GeoPoint(0, 0),
      dropoffLocation:
          data['dropoffPoint'] as GeoPoint? ?? const GeoPoint(0, 0),
      fare: (data['fare'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      collection: 'deliveries',
      packageDescription: data['parcelType'] as String?,
      weightTier: data['weightTier'] as String?,
      bookedVehicle: data['vehicleType'] as String?,
    );
  }

  // ── Gas order from 'gas_order_offers' (functions/order_offers.js) ──
  // The fare is the order total the server verified (verifiedPrice), the
  // amount settlement uses; for cash it is what the driver collects.
  factory AvailableRequest.fromGasOffer(Map<String, dynamic> data, String id) {
    return AvailableRequest(
      id: id,
      passengerId: '',
      type: RequestType.gas,
      status: 'pendingApproval',
      pickupAddress: _offerArea(data['pickupArea']),
      dropoffAddress: _offerArea(data['dropoffArea']),
      pickupLocation: data['pickupPoint'] as GeoPoint? ?? const GeoPoint(0, 0),
      dropoffLocation:
          data['dropoffPoint'] as GeoPoint? ?? const GeoPoint(0, 0),
      fare: (data['totalPrice'] as num?)?.toDouble() ?? 0.0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      collection: 'gas_orders',
      refillType: data['refillType'] as String?,
      cylinderSize: data['cylinderSize'] as String?,
      cylinderQuantity: data['quantity'] as int? ?? 1,
      deliveryFee: (data['deliveryFee'] as num?)?.toDouble(),
    );
  }

  static String _offerArea(Object? area) =>
      area is String && area.trim().isNotEmpty
          ? area
          : 'Exact address after you accept';
}

// ─────────────────────────────────────────────────────────────────────────────
// DISTANCE (display only)
// ─────────────────────────────────────────────────────────────────────────────

/// Straight-line km from the driver to a request's pickup, for display only.
/// Null when either point is missing. Eligibility (including the offer
/// radius) is dispatch_eligibility.dart's.
double? _pickupDistanceKm(GeoPoint? driverLocation, GeoPoint pickup) {
  if (driverLocation == null || !validPoint(pickup)) return null;
  return distanceKm(driverLocation, pickup);
}

String _formatDistance(double km) =>
    km < 1 ? '${(km * 1000).round()} m' : '${km.toStringAsFixed(1)} km';

// ─────────────────────────────────────────────────────────────────────────────
// PROVIDERS
// ─────────────────────────────────────────────────────────────────────────────
//
// The Firestore listeners are keyed on [RequestQuery] (what the queries
// depend on), so a location update does not re-subscribe them.
// [pendingRequestsProvider] is keyed on the whole profile (whose equality
// covers every field eligibility reads), so any change to the driver's
// location, vehicle, service, approval or job re-filters at once.

/// What the request queries depend on.
class RequestQuery extends Equatable {
  const RequestQuery({
    required this.uid,
    required this.role,
    this.serviceType,
    this.tiers = const [],
  });

  factory RequestQuery.of(DriverProfile d) => RequestQuery(
        uid: d.uid,
        role: d.role,
        serviceType: d.serviceType,
        tiers: switch (canonicalVehicle(d.vehicleTypeRaw)) {
          'motorcycle' => const ['Small'],
          'tricycle' => const ['Medium', 'Large'],
          'miniTruck' => const ['Bulk'],
          _ => const [],
        },
      );

  final String uid;
  final String? role;
  final String? serviceType;

  /// Weight tiers the driver's vehicle carries (DELIVERY_VEHICLE_TIERS).
  final List<String> tiers;

  bool get isRide => role == 'driver_hailing';
  bool get isDelivery => role == 'driver_delivery';

  @override
  List<Object?> get props => [uid, role, serviceType, tiers];
}

/// Open rides of the driver's service.
final _pendingRidesProvider = StreamProvider.autoDispose
    .family<List<AvailableRequest>, RequestQuery>((ref, q) {
  if (!q.isRide || q.serviceType == null) return Stream.value(const []);
  return FirebaseFirestore.instance
      .collection('trips')
      .where('status', isEqualTo: 'searching')
      .where('serviceType', isEqualTo: q.serviceType)
      .orderBy('createdAt', descending: true)
      .limit(20)
      .snapshots()
      .map((snap) => snap.docs
          .where((d) => d.data()['driverId'] == null)
          .map((d) => AvailableRequest.fromTripFirestore(d.data(), d.id))
          .toList());
});

/// Open deliveries of the tiers the driver's vehicle carries, from
/// delivery_offers: open delivery documents are not readable by unassigned
/// drivers (firestore.rules). The server removes an offer when its order is
/// taken or ends. One equality filter, no ordering (no composite index);
/// [eligibleRequests] sorts newest first.
final _pendingDeliveriesProvider = StreamProvider.autoDispose
    .family<List<AvailableRequest>, RequestQuery>((ref, q) {
  // No tiers (no delivery vehicle) means no deliveries, never an unfiltered
  // list.
  if (!q.isDelivery || q.tiers.isEmpty) return Stream.value(const []);
  return FirebaseFirestore.instance
      .collection('delivery_offers')
      .where('weightTier', whereIn: q.tiers)
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => AvailableRequest.fromDeliveryOffer(d.data(), d.id))
          .toList());
});

/// Open gas orders (Delivery drivers serve Gas), from gas_order_offers.
final _pendingGasProvider = StreamProvider.autoDispose
    .family<List<AvailableRequest>, RequestQuery>((ref, q) {
  if (!q.isDelivery) return Stream.value(const []);
  return FirebaseFirestore.instance
      .collection('gas_order_offers')
      .limit(50)
      .snapshots()
      .map((snap) => snap.docs
          .map((d) => AvailableRequest.fromGasOffer(d.data(), d.id))
          .toList());
});

/// The requests [driver] may accept, newest first: the three open lists,
/// filtered by the dispatch policy. A failed query is an error, never an
/// empty list.
final pendingRequestsProvider = Provider.autoDispose
    .family<AsyncValue<List<AvailableRequest>>, DriverProfile>((ref, driver) {
  final q = RequestQuery.of(driver);
  final sources = {
    'rides': ref.watch(_pendingRidesProvider(q)),
    'deliveries': ref.watch(_pendingDeliveriesProvider(q)),
    'gas orders': ref.watch(_pendingGasProvider(q)),
  };

  final failed = sources.entries.where((e) => e.value.hasError).toList();
  if (failed.isNotEmpty) {
    return AsyncValue.error(
      RequestsLoadError(failed.map((e) => e.key).toList(), failed.first.value.error!),
      failed.first.value.stackTrace ?? StackTrace.empty,
    );
  }
  if (sources.values.any((v) => v.isLoading && !v.hasValue)) {
    return const AsyncValue.loading();
  }
  return AsyncValue.data(eligibleRequests(
      driver, sources.values.expand((v) => v.value ?? const <AvailableRequest>[])));
});

/// Re-subscribes every request query of [driver] (the Retry button).
void refreshRequests(WidgetRef ref, DriverProfile driver) {
  final q = RequestQuery.of(driver);
  ref.invalidate(_pendingRidesProvider(q));
  ref.invalidate(_pendingDeliveriesProvider(q));
  ref.invalidate(_pendingGasProvider(q));
}

/// [requests] the dispatch policy lets [driver] accept, newest first.
List<AvailableRequest> eligibleRequests(
  DriverProfile driver,
  Iterable<AvailableRequest> requests,
) =>
    requests.where((r) => driverMayTake(driver, r.dispatchJob)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

/// One or more request queries failed.
class RequestsLoadError implements Exception {
  const RequestsLoadError(this.lists, this.cause);
  final List<String> lists;
  final Object cause;

  @override
  String toString() => 'Could not load ${lists.join(', ')}: $cause';
}

/// What the request list says when a query fails. A refusal by the
/// Firestore rules is not a connection problem: the server does not (yet)
/// let this account read that list, so retrying on a better network will not
/// help.
String requestsErrorMessage(Object error) {
  if (error is! RequestsLoadError) {
    return 'Could not load requests.\nCheck your connection.';
  }
  final lists = error.lists.join(', ');
  final cause = error.cause;
  if (cause is FirebaseException && cause.code == 'permission-denied') {
    return 'Could not load $lists: access was refused.\n'
        'Contact support if this continues.';
  }
  return 'Could not load $lists.\nCheck your connection.';
}

// ─────────────────────────────────────────────────────────────────────────────
// ACCEPTANCE
// ─────────────────────────────────────────────────────────────────────────────

/// The callable that accepts a request from [collection], and its id field.
(String, String) acceptCallableFor(String collection) => switch (collection) {
      'trips' => ('acceptRide', 'tripId'),
      'deliveries' => ('acceptDelivery', 'deliveryId'),
      _ => ('acceptGasOrder', 'orderId'),
    };

/// What the driver is told when the server refuses an acceptance.
String acceptRefusalMessage(String? reason, String? detail) =>
    switch (reason) {
      'order_not_found' ||
      'order_unavailable' =>
        'This request is no longer available.',
      'order_already_assigned' =>
        'This request was just accepted by another driver.',
      'driver_not_found' => 'Your driver profile could not be found.',
      'vehicle_not_eligible' => 'Your vehicle cannot take this request.',
      'driver_on_job' => 'Finish your current job before accepting another.',
      'outside_radius' => detail == 'driver_location_invalid'
          ? 'We could not confirm your location. Check that location access '
              'is on and try again.'
          : 'You are too far from this request to accept it.',
      'driver_not_eligible' => switch (detail) {
          'driver_unavailable' => 'Go online to accept requests.',
          'driver_not_approved' =>
            'Your account is not approved to take requests.',
          'wrong_service' || 'wrong_ride_service' =>
            'This request is not for your service.',
          _ => 'You are not currently eligible to accept this request.',
        },
      _ => 'This request could not be accepted.',
    };

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
            const Expanded(
              child: Text(
                'Available Requests',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.3,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            if (isOnline) _LiveDot(),
          ],
        ),
        const SizedBox(height: 12),
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
    // Nothing could be accepted (not approved, on a job, vehicle or
    // location missing): say why rather than show "searching".
    final block = requestListBlock(driver);
    if (block != null) {
      return _EmptyState(
        icon: Icons.info_outline_rounded,
        message: block,
        iconColor: AppTheme.textSecondary,
      );
    }

    final requestsAsync = ref.watch(pendingRequestsProvider(driver));

    return requestsAsync.when(
      loading: () => const _SearchingState(),
      error: (e, _) => _EmptyState(
        icon: Icons.cloud_off_rounded,
        message: requestsErrorMessage(e),
        iconColor: AppColors.errorColor,
        action: TextButton(
          onPressed: () => refreshRequests(ref, driver),
          child: const Text('Retry'),
        ),
      ),
      data: (requests) => requests.isEmpty
          ? const _SearchingState()
          : ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: requests.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (_, i) => _RequestCard(
                request: requests[i],
                driverUid: driver.uid,
                driverLocation: driver.dispatchLocation,
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
    this.driverLocation,
  });
  final AvailableRequest request;
  final String driverUid;
  final GeoPoint? driverLocation; // display only (pickup distance)

  @override
  State<_RequestCard> createState() => _RequestCardState();
}

class _RequestCardState extends State<_RequestCard>
    with SingleTickerProviderStateMixin {
  bool _isAccepting = false;

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

  /// Accepts through the server (accept_job.js): eligibility, the offer
  /// radius and the driver's busy state are checked and set there, in one
  /// transaction.
  Future<void> _acceptRequest() async {
    HapticFeedback.mediumImpact();
    setState(() => _isAccepting = true);
    final nav = Navigator.of(context, rootNavigator: true);

    try {
      final req = widget.request;
      final (name, idField) = acceptCallableFor(req.collection);
      final result = await FirebaseFunctions.instanceFor(region: 'europe-west2')
          .httpsCallable(name)
          .call({idField: req.id});
      final data = Map<String, dynamic>.from(result.data as Map);

      if (data['success'] != true) {
        throw Exception(acceptRefusalMessage(
            data['reason'] as String?, data['detail'] as String?));
      }
      _navigateToActiveScreenWithNav(nav);
    } on FirebaseFunctionsException catch (e) {
      if (mounted) {
        final message = switch (e.code) {
          'unauthenticated' =>
            'Please sign in again before accepting this request.',
          'invalid-argument' => 'This request could not be accepted.',
          'internal' || 'unavailable' || 'deadline-exceeded' =>
            'Unable to accept this request right now. Please try again.',
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
    final service = _ServiceStyle.of(req);
    final distanceKm = _pickupDistanceKm(widget.driverLocation, req.pickupLocation);
    final isGas = req.type == RequestType.gas;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.divider),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: service identity + fare ──
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ServiceIcon(service: service),
                const SizedBox(width: 12),
                // The fare keeps priority on narrow screens: the label
                // truncates first, then the fare scales down.
                Expanded(
                  flex: 2,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        service.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: service.accent,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (service.detail != null) service.detail!,
                          _timeAgo(req.createdAt),
                        ].join(' · '),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Flexible(
                  flex: 3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.topRight,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'GH₵ ${req.fare.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 21,
                            letterSpacing: -0.4,
                            color: AppTheme.textPrimary,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                        Text(
                          isGas ? 'Order total' : 'Est. fare',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            // ── Distance to pickup / passengers ──
            if (distanceKm != null ||
                (req.type == RequestType.ride && req.passengerCount > 1)) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (distanceKm != null)
                    _InfoChip(
                      icon: Icons.near_me_rounded,
                      text:
                          // Delivery and Gas requests show a point rounded
                          // to about 1 km (order_offers.js).
                          '${req.type == RequestType.ride ? '' : '~'}'
                          '${_formatDistance(distanceKm)} to ${isGas ? 'station' : 'pickup'}',
                      emphasis: true,
                    ),
                  if (req.type == RequestType.ride && req.passengerCount > 1)
                    _InfoChip(
                      icon: Icons.person_rounded,
                      text: '${req.passengerCount} passengers',
                    ),
                ],
              ),
            ],

            const SizedBox(height: 14),

            // ── Route ──
            _LocationRow(
              icon: Icons.trip_origin_rounded,
              iconColor: AppTheme.primaryDark,
              label: isGas ? 'Station' : 'Pickup',
              address: req.pickupAddress,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 8, top: 2, bottom: 2),
              child: Container(width: 2, height: 12, color: AppTheme.divider),
            ),
            _LocationRow(
              icon: Icons.location_on_rounded,
              iconColor: AppTheme.danger,
              label: 'Dropoff',
              address: req.dropoffAddress,
            ),

            if (req.type == RequestType.delivery &&
                req.photoUrl != null &&
                req.photoUrl!.trim().isNotEmpty) ...[
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => _showParcelPhoto(req.photoUrl!),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 96,
                    width: double.infinity,
                    color: AppTheme.background,
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
                              color: AppTheme.textSecondary,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          bottom: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.7),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.zoom_in_rounded,
                                  size: 16,
                                  color: Colors.white,
                                ),
                                SizedBox(width: 4),
                                Text(
                                  'View parcel',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
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
              const SizedBox(height: 12),
              _DeliveryExtras(request: req, service: service),
            ],

            if (isGas) ...[
              const SizedBox(height: 12),
              _GasExtras(request: req, service: service),
            ],

            const SizedBox(height: 16),

            // ── Accept button ──
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _isAccepting ? null : _acceptRequest,
                // Solid while accepting so the spinner stays visible.
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.primaryDark,
                  foregroundColor: AppTheme.onPrimary,
                  disabledBackgroundColor: AppTheme.primaryDark,
                  minimumSize: const Size.fromHeight(52),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isAccepting
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppTheme.onPrimary,
                        ),
                      )
                    : Text(
                        'Accept ${_requestLabel(req.type)}',
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
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
// SERVICE IDENTITY
// Ride is CTSGo green, delivery blue and gas orange (passenger app values).
// Accents are used for text and icons on white and pass 4.5:1.
// ─────────────────────────────────────────────────────────────────────────────

class _ServiceStyle {
  const _ServiceStyle({
    required this.label,
    required this.icon,
    required this.accent,
    required this.tint,
    this.detail,
  });

  final String label;
  final IconData icon;
  final Color accent;
  final Color tint;
  final String? detail; // e.g. the ride's service type

  static const _deliveryAccent = Color(0xFF0369A1); // 5.9:1 on white
  static const _deliveryTint = Color(0xFFE0F2FE);
  static const _gasAccent = Color(0xFFC2410C); // 5.2:1 on white
  static const _gasTint = Color(0xFFFFF1E6);

  static _ServiceStyle of(AvailableRequest req) => switch (req.type) {
        RequestType.ride => _ride(req.serviceType),
        RequestType.delivery => const _ServiceStyle(
            label: 'Delivery',
            icon: Icons.local_shipping_rounded,
            accent: _deliveryAccent,
            tint: _deliveryTint,
          ),
        RequestType.gas => const _ServiceStyle(
            label: 'Gas Order',
            icon: Icons.propane_tank_rounded,
            accent: _gasAccent,
            tint: _gasTint,
          ),
      };

  static _ServiceStyle _ride(String? serviceType) {
    final type = serviceType?.toLowerCase();
    final (IconData icon, String? detail) = switch (type) {
      'okada' => (Icons.two_wheeler_rounded, 'Okada'),
      'pragyia' => (Icons.electric_rickshaw_rounded, 'Pragyia'),
      'taxi' => (Icons.local_taxi_rounded, 'Taxi'),
      _ => (Icons.directions_car_rounded, null),
    };
    return _ServiceStyle(
      label: 'Ride',
      icon: icon,
      accent: AppTheme.primaryDark,
      tint: AppTheme.primaryLight,
      detail: detail,
    );
  }
}

class _ServiceIcon extends StatelessWidget {
  const _ServiceIcon({required this.service});
  final _ServiceStyle service;

  @override
  Widget build(BuildContext context) => Container(
        width: 46,
        height: 46,
        decoration: BoxDecoration(
          color: service.tint,
          borderRadius: BorderRadius.circular(13),
        ),
        child: Icon(service.icon, color: service.accent, size: 26),
      );
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({
    required this.icon,
    required this.text,
    this.emphasis = false,
  });

  final IconData icon;
  final String text;
  final bool emphasis;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: emphasis ? AppTheme.primaryLight : AppTheme.background,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: emphasis ? AppTheme.primarySubtle : AppTheme.divider,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: emphasis ? AppTheme.primaryDark : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: emphasis ? FontWeight.w700 : FontWeight.w500,
                  color: emphasis ? AppTheme.primaryDeep : AppTheme.textPrimary,
                ),
              ),
            ),
          ],
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// DELIVERY EXTRAS
// ─────────────────────────────────────────────────────────────────────────────

class _DeliveryExtras extends StatelessWidget {
  const _DeliveryExtras({required this.request, required this.service});

  final AvailableRequest request;
  final _ServiceStyle service;

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

    return _ExtrasPanel(
      children: [
        // ── Parcel ──
        const _ExtrasHeading(icon: Icons.inventory_2_rounded, title: 'Parcel'),
        const SizedBox(height: 6),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                hasParcel ? request.packageDescription!.trim() : 'Parcel',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.textPrimary,
                ),
              ),
            ),
            if (hasWeight) ...[
              const SizedBox(width: 8),
              _Tag(text: request.weightTier!.toUpperCase(), service: service),
            ],
          ],
        ),

        // ── Receiver ──
        if (hasRecipient || hasPhone) ...[
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppTheme.divider),
          const SizedBox(height: 10),
          const _ExtrasHeading(icon: Icons.person_rounded, title: 'Receiver'),
          const SizedBox(height: 6),
          if (hasRecipient)
            Text(
              request.recipientName!.trim(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          if (hasPhone)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                request.recipientPhone!.trim(),
                style: const TextStyle(
                  fontSize: 14,
                  color: AppTheme.textSecondary,
                ),
              ),
            ),
        ],
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// GAS EXTRAS
// ─────────────────────────────────────────────────────────────────────────────

class _GasExtras extends StatelessWidget {
  const _GasExtras({required this.request, required this.service});
  final AvailableRequest request;
  final _ServiceStyle service;

  @override
  Widget build(BuildContext context) => _ExtrasPanel(
        children: [
          Row(
            children: [
              Icon(Icons.propane_tank_rounded, size: 18, color: service.accent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${request.cylinderSize ?? 'Gas cylinder'}'
                  ' × ${request.cylinderQuantity ?? 1}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Tag(text: 'GAS ORDER', service: service),
            ],
          ),
        ],
      );
}

class _ExtrasPanel extends StatelessWidget {
  const _ExtrasPanel({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: children,
        ),
      );
}

class _ExtrasHeading extends StatelessWidget {
  const _ExtrasHeading({required this.icon, required this.title});
  final IconData icon;
  final String title;

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: AppTheme.textSecondary),
          const SizedBox(width: 6),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: AppTheme.textSecondary,
            ),
          ),
        ],
      );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.text, required this.service});
  final String text;
  final _ServiceStyle service;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: service.tint,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
            color: service.accent,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// OFFLINE CARD
// ─────────────────────────────────────────────────────────────────────────────

class _OfflineCard extends StatelessWidget {
  const _OfflineCard({required this.onGoOnline});
  final VoidCallback onGoOnline;

  @override
  Widget build(BuildContext context) => _StateCard(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppTheme.background,
              shape: BoxShape.circle,
              border: Border.all(color: AppTheme.divider),
            ),
            child: const Icon(Icons.power_settings_new_rounded,
                size: 28, color: AppTheme.textSecondary),
          ),
          const SizedBox(height: 12),
          const Text(
            "You're offline",
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16.5,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            'Go online to start receiving requests.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onGoOnline,
            icon: const Icon(Icons.power_settings_new_rounded),
            label: const Text('Go Online'),
          ),
        ],
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
  Widget build(BuildContext context) => _StateCard(
        children: [
          FadeTransition(
            opacity: _anim,
            child: const Icon(Icons.radar_rounded,
                size: 48, color: AppTheme.primary),
          ),
          const SizedBox(height: 10),
          const Text(
            'Searching for requests nearby...',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
        ],
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
  Widget build(BuildContext context) => _StateCard(
        children: [
          Icon(icon, size: 40, color: iconColor),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 14,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: 8),
            action!,
          ],
        ],
      );
}

class _StateCard extends StatelessWidget {
  const _StateCard({required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 28),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(children: children),
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
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: AppTheme.primaryLight,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppTheme.primarySubtle),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: _c,
              child: Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  color: AppTheme.primary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
            const SizedBox(width: 6),
            const Text(
              'LIVE',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppTheme.primaryDeep,
                letterSpacing: 1,
              ),
            ),
          ],
        ),
      );
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
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 18, color: iconColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  address,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
}
