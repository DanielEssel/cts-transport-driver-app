// lib/features/jobs/screens/active_delivery_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cts_transport_driver_app/core/services/marker_service.dart';

import '../../../core/constants/app_colors.dart';
import '../../../app/app_theme.dart';

import 'package:cts_transport_driver_app/core/services/route_service.dart';

// ── Delivery status strings — must match passenger app exactly ───────────────
class _DS {
  static const driverAssigned = 'driverAssigned';
  static const pickupEnroute = 'pickupEnroute';
  static const arrivedAtPickup = 'arrivedAtPickup';
  static const packagePicked = 'packagePicked';
  static const deliveryEnroute = 'deliveryEnroute';
  static const arrivedAtDropoff = 'arrivedAtDropoff';
  static const completed = 'completed';
  static const cancelled = 'cancelled';
}

class ActiveDeliveryScreen extends StatefulWidget {
  final String deliveryId;

  const ActiveDeliveryScreen({super.key, required this.deliveryId});

  @override
  State<ActiveDeliveryScreen> createState() => _ActiveDeliveryScreenState();
}

class _ActiveDeliveryScreenState extends State<ActiveDeliveryScreen> {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;
  List<LatLng> _routePoints = [];
final _routeService = RouteService();

  Map<String, dynamic>? _delivery;
  String _status = _DS.driverAssigned;

  GoogleMapController? _mapController;
  LatLng? _driverPos;
  bool _isLoading = true;
  bool _isUpdating = false;

  StreamSubscription<DocumentSnapshot>? _deliverySub;
  StreamSubscription<Position>? _locationSub;
  Timer? _locationThrottle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await MarkerService.instance.warmUp(context);
      if (mounted) setState(() {});
    });
    _subscribeToDelivery();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _deliverySub?.cancel();
    _locationSub?.cancel();
    _locationThrottle?.cancel();
    super.dispose();
  }

  // ── Subscriptions ─────────────────────────────────────────────────────────

  void _subscribeToDelivery() {
    _deliverySub = _db
    .collection('deliveries')
    .doc(widget.deliveryId)
    .snapshots()
    .listen((doc) {
  if (!doc.exists || !mounted) return;
  setState(() {
    _delivery = doc.data();
    _status = _delivery?['status'] as String? ?? _DS.driverAssigned;
    _isLoading = false;
  });
  _fetchRoute();
    });
  }

  void _startLocationUpdates() {
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((pos) {
      if (!mounted) return;
      setState(() => _driverPos = LatLng(pos.latitude, pos.longitude));
      // Throttle Firestore writes to once every 5 seconds.
      if (_locationThrottle?.isActive ?? false) return;
      _locationThrottle = Timer(const Duration(seconds: 5), () {
        _writeLocation(pos);
      });
    });
  }

  Future<void> _writeLocation(Position pos) async {
    try {
      await _db.collection('deliveries').doc(widget.deliveryId).update({
        'driverCurrentLocation': GeoPoint(pos.latitude, pos.longitude),
        'driverHeading': pos.heading,
        'driverLocationUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }



void _fetchRoute() {
  final pickup = _pickupLatLng;
  final dropoff = _dropoffLatLng;
  if (pickup == null || dropoff == null || _routePoints.isNotEmpty) return;
  _routeService.getRoute(pickup, dropoff).then((result) {
    if (result != null && mounted) {
      setState(() => _routePoints = result.points);
    }
  });
}
  // ── Status progression ─────────────────────────────────────────────────────

  String get _nextStatus => switch (_status) {
        _DS.driverAssigned => _DS.pickupEnroute,
        _DS.pickupEnroute => _DS.arrivedAtPickup,
        _DS.arrivedAtPickup => _DS.packagePicked,
        _DS.packagePicked => _DS.deliveryEnroute,
        _DS.deliveryEnroute => _DS.arrivedAtDropoff,
        _DS.arrivedAtDropoff => _DS.completed,
        _ => _DS.completed,
      };

  String get _ctaLabel => switch (_status) {
        _DS.driverAssigned => 'Start — En Route to Pickup',
        _DS.pickupEnroute => 'Arrived at Pickup',
        _DS.arrivedAtPickup => 'Parcel Collected',
        _DS.packagePicked => 'Start Delivery',
        _DS.deliveryEnroute => 'Arrived at Drop-off',
        _DS.arrivedAtDropoff => 'Mark as Delivered',
        _ => 'Done',
      };

  String get _statusLabel => switch (_status) {
        _DS.driverAssigned => 'Delivery Assigned',
        _DS.pickupEnroute => 'En Route to Pickup',
        _DS.arrivedAtPickup => 'At Pickup Location',
        _DS.packagePicked => 'Parcel Collected',
        _DS.deliveryEnroute => 'En Route to Drop-off',
        _DS.arrivedAtDropoff => 'At Drop-off Location',
        _DS.completed => 'Completed',
        _ => 'In Progress',
      };

  Future<void> _advanceStatus() async {
    if (_isUpdating) return;
    if (_status == _DS.completed) {
      Navigator.popUntil(context, (r) => r.isFirst);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isUpdating = true);

    try {
      final next = _nextStatus;
      final data = <String, dynamic>{
        'status': next,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add timestamps for key events
      if (next == _DS.packagePicked) {
        data['pickedUpAt'] = FieldValue.serverTimestamp();
      } else if (next == _DS.completed) {
        // OTP verification before completing
        final storedOtp = _delivery?['deliveryOtp'] as String?;
        if (storedOtp != null && storedOtp.isNotEmpty) {
          final enteredOtp = await _showOtpDialog();
          if (enteredOtp == null) {
            setState(() => _isUpdating = false);
            return;
          }
          if (enteredOtp != storedOtp) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text(
                    'Incorrect OTP. Ask the recipient for the correct code.'),
                backgroundColor: Color(0xFFDC2626),
              ));
            }
            setState(() => _isUpdating = false);
            return;
          }
          data['otpSubmitted'] = enteredOtp;
          data['otpVerifiedAt'] = FieldValue.serverTimestamp();
        }
        data['completedAt'] = FieldValue.serverTimestamp();
        data['actualFare'] = _delivery?['estimatedFare'];
        // CF onDeliveryCompleted handles wallet + driver credit
      }

      await _db.collection('deliveries').doc(widget.deliveryId).update(data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Failed to update: $e'),
          backgroundColor: AppColors.errorColor,
        ));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _cancelDelivery() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Delivery?'),
        content:
            const Text('Are you sure? This may affect your acceptance rate.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Yes, Cancel'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    await _db.collection('deliveries').doc(widget.deliveryId).update({
      'status': _DS.cancelled,
      'cancelledAt': FieldValue.serverTimestamp(),
      'cancelReason': 'Cancelled by driver',
    });

    if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
  }

  Future<String?> _showOtpDialog() async {
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Enter Delivery OTP',
            style: TextStyle(fontWeight: FontWeight.w800)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Ask the recipient for their 4-digit OTP to confirm delivery.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              maxLength: 4,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                hintText: '0000',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF16A34A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: Color(0xFF16A34A), width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF16A34A)),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Future<void> _callContact() async {
    final isDropoff = [
      _DS.deliveryEnroute,
      _DS.arrivedAtDropoff,
    ].contains(_status);

    String? phone;
    if (isDropoff) {
      phone = _delivery?['receiverPhone'] as String?;
    } else {
      phone = _delivery?['senderPhone'] as String?;
    }

    if (phone == null || phone.isEmpty) return;
    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  LatLng? get _pickupLatLng {
    final loc = _delivery?['pickupLocation'] as GeoPoint?;
    return loc == null ? null : LatLng(loc.latitude, loc.longitude);
  }

  LatLng? get _dropoffLatLng {
    final loc = _delivery?['dropoffLocation'] as GeoPoint?;
    return loc == null ? null : LatLng(loc.latitude, loc.longitude);
  }

  bool get _headingToDropoff => [
        _DS.packagePicked,
        _DS.deliveryEnroute,
        _DS.arrivedAtDropoff
      ].contains(_status);

  Future<void> _navigateToLeg() async {
    final dest = _headingToDropoff ? _dropoffLatLng : _pickupLatLng;
    if (dest == null) return;
    final uri = Uri.parse(
        'google.navigation:q=${dest.latitude},${dest.longitude}&mode=d');
    try {
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
        return;
      }
    } catch (_) {}
    final fallback = Uri.parse(
        'https://www.google.com/maps/dir/?api=1&destination=${dest.latitude},${dest.longitude}&travelmode=driving');
    if (await canLaunchUrl(fallback)) {
      await launchUrl(fallback, mode: LaunchMode.externalApplication);
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_status == _DS.completed) {
      return _CompletedScreen(
        fare: (_delivery?['estimatedFare'] as num?)?.toDouble() ?? 0,
        onDone: () => Navigator.popUntil(context, (r) => r.isFirst),
      );
    }

    final pickupAddress = _delivery?['pickupAddress'] as String? ?? '—';
    final dropoffAddress = _delivery?['dropoffAddress'] as String? ?? '—';
    final parcelType = _delivery?['parcelType'] as String? ?? 'Package';
    final weightTier = _delivery?['weightTier'] as String? ?? '';
    final isFragile = _delivery?['isFragile'] as bool? ?? false;
    final receiverName = _delivery?['receiverName'] as String?;
    final receiverPhone = _delivery?['receiverPhone'] as String?;
    final estimatedFare =
        (_delivery?['estimatedFare'] as num?)?.toDouble() ?? 0;
    final notes = _delivery?['notes'] as String?;

    final isAtPickup = [
      _DS.pickupEnroute,
      _DS.arrivedAtPickup,
    ].contains(_status);

    final isDropoffLeg =
        [_DS.deliveryEnroute, _DS.arrivedAtDropoff].contains(_status);

    return Scaffold(
      backgroundColor: AppTheme.background,
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_statusLabel),
        backgroundColor: AppTheme.surface.withValues(alpha: 0.95),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_rounded),
            onPressed: _callContact,
            tooltip: isAtPickup ? 'Call sender' : 'Call receiver',
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Full-bleed map, fills the whole screen behind everything ──
          Positioned.fill(
            child: _buildMapArea(
              isDropoff: isDropoffLeg,
              address: isDropoffLeg ? dropoffAddress : pickupAddress,
            ),
          ),

          // ── Step bar floats over the top of the map, under the AppBar ──
          Positioned(
            top: kToolbarHeight + MediaQuery.of(context).padding.top,
            left: 0,
            right: 0,
            child: Container(
              color: AppTheme.surface.withValues(alpha: 0.95),
              child: _DeliveryStepBar(status: _status),
            ),
          ),

          // ── Draggable details sheet ──
          DraggableScrollableSheet(
            initialChildSize: 0.36,
            minChildSize: 0.16,
            maxChildSize: 0.85,
            snap: true,
            snapSizes: const [0.16, 0.36, 0.85],
            builder: (context, scrollController) => Container(
              decoration: BoxDecoration(
                color: AppTheme.cardBackground,
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 20,
                    offset: const Offset(0, -6),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // Drag handle
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.divider,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                      child: Column(
                        children: [
                          _buildParcelCard(
                            parcelType: parcelType,
                            weightTier: weightTier,
                            isFragile: isFragile,
                            receiverName: receiverName,
                            receiverPhone: receiverPhone,
                            notes: notes,
                            isAtDropoff: isDropoffLeg,
                          ),
                          const SizedBox(height: 12),
                          _buildRouteCard(
                            pickupAddress: pickupAddress,
                            dropoffAddress: dropoffAddress,
                            fare: estimatedFare,
                          ),
                          const SizedBox(height: 20),
                          SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              onPressed: _isUpdating ? null : _advanceStatus,
                              icon: _isUpdating
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2, color: Colors.white))
                                  : Icon(_ctaIcon),
                              label: Text(_ctaLabel),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.green.withValues(alpha: 0.9),
                                padding:
                                    const EdgeInsets.symmetric(vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12)),
                              ),
                            ),
                          ),
                          if ([_DS.driverAssigned, _DS.pickupEnroute]
                              .contains(_status)) ...[
                            const SizedBox(height: 10),
                            SizedBox(
                              width: double.infinity,
                              child: OutlinedButton(
                                onPressed: _cancelDelivery,
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.red,
                                  side: const BorderSide(color: Colors.red),
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12)),
                                ),
                                child: const Text('Cancel Delivery'),
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData get _ctaIcon => switch (_status) {
        _DS.driverAssigned => Icons.directions_rounded,
        _DS.pickupEnroute => Icons.location_on_rounded,
        _DS.arrivedAtPickup => Icons.inventory_2_rounded,
        _DS.packagePicked => Icons.local_shipping_rounded,
        _DS.deliveryEnroute => Icons.location_on_rounded,
        _DS.arrivedAtDropoff => Icons.check_circle_rounded,
        _ => Icons.home_rounded,
      };

  Widget _buildMapArea({required bool isDropoff, required String address}) {
    final hasPoints = _pickupLatLng != null && _dropoffLatLng != null;
    return Stack(
      children: [
        if (hasPoints)
  GoogleMap(
    onMapCreated: (c) {
      _mapController = c;
      final bounds = LatLngBounds(
        southwest: LatLng(
          _pickupLatLng!.latitude < _dropoffLatLng!.latitude
              ? _pickupLatLng!.latitude
              : _dropoffLatLng!.latitude,
          _pickupLatLng!.longitude < _dropoffLatLng!.longitude
              ? _pickupLatLng!.longitude
              : _dropoffLatLng!.longitude,
        ),
        northeast: LatLng(
          _pickupLatLng!.latitude > _dropoffLatLng!.latitude
              ? _pickupLatLng!.latitude
              : _dropoffLatLng!.latitude,
          _pickupLatLng!.longitude > _dropoffLatLng!.longitude
              ? _pickupLatLng!.longitude
              : _dropoffLatLng!.longitude,
        ),
      );
      Future.delayed(const Duration(milliseconds: 300), () {
        c.animateCamera(CameraUpdate.newLatLngBounds(bounds, 80));
      });
    },
    initialCameraPosition: CameraPosition(
      target: isDropoff ? _dropoffLatLng! : _pickupLatLng!,
      zoom: 13,
    ),
    markers: {
      Marker(
        markerId: const MarkerId('pickup'),
        position: _pickupLatLng!,
        icon: MarkerService.instance.pickup(),
        anchor: const Offset(0.5, 1.0),
        infoWindow: const InfoWindow(title: 'Pickup'),
      ),
      Marker(
        markerId: const MarkerId('dropoff'),
        position: _dropoffLatLng!,
        icon: MarkerService.instance.dropoff(),
        anchor: const Offset(0.5, 1.0),
        infoWindow: const InfoWindow(title: 'Drop-off'),
      ),
      if (_driverPos != null)
        Marker(
          markerId: const MarkerId('driver'),
          position: _driverPos!,
          icon: MarkerService.instance.vehicle('delivery'),
          anchor: const Offset(0.5, 0.5),
          flat: true,
          infoWindow: const InfoWindow(title: 'You'),
        ),
    },
    polylines: {
      if (_routePoints.isNotEmpty)
        Polyline(
          polylineId: const PolylineId('route'),
          points: _routePoints,
          color: AppTheme.primary,
          width: 4,
        ),
    },
    myLocationButtonEnabled: false,
    zoomControlsEnabled: false,
    mapToolbarEnabled: false,
    compassEnabled: false,
    padding: const EdgeInsets.only(bottom: 140),
  )
else
  Container(color: AppTheme.surface),
        Align(
          alignment:
              const Alignment(0.9, 0.0), // right side, vertically centered
          child: FloatingActionButton.extended(
            heroTag: 'deliveryNav',
            onPressed: _navigateToLeg,
            backgroundColor: AppTheme.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.navigation_rounded, size: 18),
            label:
                Text(isDropoff ? 'Navigate to Drop-off' : 'Navigate to Pickup'),
          ),
        ),
      ],
    );
  }

  Widget _buildParcelCard({
    required String parcelType,
    required String weightTier,
    required bool isFragile,
    required String? receiverName,
    required String? receiverPhone,
    required String? notes,
    required bool isAtDropoff,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.inventory_2_rounded,
                      color: AppTheme.primary, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(parcelType,
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          )),
                      Row(
                        children: [
                          if (weightTier.isNotEmpty)
                            _Chip(
                                label: weightTier.toUpperCase(),
                                color: AppTheme.primary),
                          if (isFragile) ...[
                            const SizedBox(width: 6),
                            const _Chip(
                                label: '⚠ Fragile', color: AppTheme.warning),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (receiverName != null || receiverPhone != null) ...[
              const Divider(height: 20),
              Row(
                children: [
                  const Icon(Icons.person_rounded,
                      size: 16, color: AppTheme.textSecondary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isAtDropoff ? 'Receiver' : 'Sender',
                          style: const TextStyle(
                              fontSize: 11, color: AppTheme.textSecondary),
                        ),
                        if (receiverName != null)
                          Text(receiverName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              )),
                        if (receiverPhone != null)
                          Text(receiverPhone,
                              style: const TextStyle(
                                  fontSize: 13, color: AppTheme.textSecondary)),
                      ],
                    ),
                  ),
                  if (receiverPhone != null)
                    GestureDetector(
                      onTap: _callContact,
                      child: Container(
                        width: 38,
                        height: 38,
                        decoration: const BoxDecoration(
                          color: AppTheme.primaryLight,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.phone_rounded,
                            color: AppTheme.primary, size: 18),
                      ),
                    ),
                ],
              ),
            ],
            if (notes != null && notes.isNotEmpty) ...[
              const Divider(height: 20),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppTheme.warningLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('📝 $notes',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.warning,
                    )),
              ),
            ],
          ],
        ),
      );

  Widget _buildRouteCard({
    required String pickupAddress,
    required String dropoffAddress,
    required double fare,
  }) =>
      Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.cardBackground,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.divider),
        ),
        child: Column(
          children: [
            _RouteRow(
              dot: Colors.green,
              label: 'Pickup',
              address: pickupAddress,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 4, top: 4, bottom: 4),
              child: Container(width: 2, height: 16, color: AppTheme.divider),
            ),
            _RouteRow(
              dot: AppTheme.primary,
              label: 'Drop-off',
              address: dropoffAddress,
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Fare',
                    style: TextStyle(color: AppTheme.textSecondary)),
                Text(
                  'GH₵ ${fare.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                    color: AppTheme.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

// ── Step bar ──────────────────────────────────────────────────────────────────

class _DeliveryStepBar extends StatelessWidget {
  final String status;
  const _DeliveryStepBar({required this.status});

  static const _steps = [
    ('En Route', _DS.pickupEnroute),
    ('At Pickup', _DS.arrivedAtPickup),
    ('Collected', _DS.packagePicked),
    ('Delivering', _DS.deliveryEnroute),
    ('Delivered', _DS.completed),
  ];

  int get _currentStep {
    final idx = _steps.indexWhere((s) => s.$2 == status);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) => Container(
        color: AppTheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: List.generate(_steps.length * 2 - 1, (i) {
            if (i.isOdd) {
              final stepIdx = (i - 1) ~/ 2;
              return Expanded(
                child: Container(
                  height: 2,
                  color: stepIdx < _currentStep
                      ? AppTheme.primary
                      : AppTheme.divider,
                ),
              );
            }
            final stepIdx = i ~/ 2;
            final done = stepIdx < _currentStep;
            final active = stepIdx == _currentStep;
            return Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? AppTheme.primary
                        : active
                            ? AppTheme.primaryLight
                            : AppTheme.divider,
                    border: active
                        ? Border.all(color: AppTheme.primary, width: 2)
                        : null,
                  ),
                  child: Icon(
                    done ? Icons.check_rounded : Icons.circle,
                    size: done ? 14 : 8,
                    color: done
                        ? Colors.white
                        : active
                            ? AppTheme.primary
                            : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _steps[stepIdx].$1,
                  style: TextStyle(
                    fontSize: 9,
                    fontWeight:
                        active || done ? FontWeight.w700 : FontWeight.w400,
                    color: active || done
                        ? AppTheme.primary
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            );
          }),
        ),
      );
}

// ── Completed screen ──────────────────────────────────────────────────────────

class _CompletedScreen extends StatelessWidget {
  final double fare;
  final VoidCallback onDone;
  const _CompletedScreen({required this.fare, required this.onDone});

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: AppTheme.background,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: const BoxDecoration(
                        color: AppTheme.primaryLight, shape: BoxShape.circle),
                    child: const Icon(Icons.inventory_rounded,
                        size: 50, color: AppTheme.primary),
                  ),
                  const SizedBox(height: 24),
                  const Text('Delivery Completed!',
                      style:
                          TextStyle(fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text(
                    'Parcel delivered successfully.\nEarnings added to your wallet.',
                    textAlign: TextAlign.center,
                    style:
                        TextStyle(fontSize: 15, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryLight,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: AppTheme.primary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text('You earned',
                            style: TextStyle(
                                color: AppTheme.primaryDark, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          'GH₵ ${fare.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize: 36,
                            fontWeight: FontWeight.w900,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: onDone,
                      style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16)),
                      child: const Text('Back to Home'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _RouteRow extends StatelessWidget {
  final Color dot;
  final String label;
  final String address;
  const _RouteRow({
    required this.dot,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 10,
            height: 10,
            margin: const EdgeInsets.only(top: 3),
            decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.textSecondary)),
                Text(address,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w500),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w700, color: color)),
      );
}
