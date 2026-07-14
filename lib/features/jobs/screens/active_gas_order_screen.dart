// lib/features/jobs/screens/active_gas_order_screen.dart

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

class _GS {
  static const driverAssigned = 'driverAssigned';
  static const driverEnRoute  = 'driverEnRoute';
  static const driverArrived  = 'driverArrived';
  static const pickedUp       = 'pickedUp';
  static const atStation      = 'atStation';
  static const refilling      = 'refilling';
  static const returning      = 'returning';
  static const delivered      = 'delivered';
  static const cancelled      = 'cancelled';
}

class ActiveGasOrderScreen extends StatefulWidget {
  final String orderId;
  const ActiveGasOrderScreen({super.key, required this.orderId});

  @override
  State<ActiveGasOrderScreen> createState() => _ActiveGasOrderScreenState();
}

class _ActiveGasOrderScreenState extends State<ActiveGasOrderScreen> {
  final _db  = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  Map<String, dynamic>? _order;
  String _status     = _GS.driverAssigned;
  bool   _isLoading  = true;
  bool   _isUpdating = false;

  GoogleMapController? _mapController;
  LatLng? _driverPos;

  StreamSubscription<DocumentSnapshot>? _orderSub;
  StreamSubscription<Position>?         _locationSub;
   Timer? _locationThrottle;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await MarkerService.instance.warmUp(context);
      if (mounted) setState(() {});
    });
    _subscribeToOrder();
    _startLocationUpdates();
  }

 @override
  void dispose() {
    _orderSub?.cancel();
    _locationSub?.cancel();
    _locationThrottle?.cancel();
    super.dispose();
  }

  void _subscribeToOrder() {
    _orderSub = _db
        .collection('gas_orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || !mounted) return;
      setState(() {
        _order     = doc.data();
        _status    = _order?['status'] as String? ?? _GS.driverAssigned;
        _isLoading = false;
      });
    });
  }

  void _startLocationUpdates() {
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy:       LocationAccuracy.high,
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
      await _db.collection('gas_orders').doc(widget.orderId).update({
        'driverCurrentLocation':   GeoPoint(pos.latitude, pos.longitude),
        'driverHeading':           pos.heading,
        'driverLocationUpdatedAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }


  // Two flows — must match passenger GasRefillType.steps exactly.
  //  • pickupAndReturn → full round trip
  //  • everything else → simple drop-off
  static List<(String, String)> stepsFor(String refillType) {
    if (refillType == 'pickupAndReturn') {
      return const [
        ('En Route',   _GS.driverEnRoute),
        ('Arrived',    _GS.driverArrived),
        ('Collected',  _GS.pickedUp),
        ('At Station', _GS.atStation),
        ('Refilling',  _GS.refilling),
        ('Returning',  _GS.returning),
        ('Delivered',  _GS.delivered),
      ];
    }
    return const [
      ('En Route',  _GS.driverEnRoute),
      ('Arrived',   _GS.driverArrived),
      ('Delivered', _GS.delivered),
    ];
  }

  String get _refillType => _order?['refillType'] as String? ?? '';

  String get _nextStatus {
    final steps = stepsFor(_refillType);
    if (_status == _GS.driverAssigned) return steps.first.$2;
    final idx = steps.indexWhere((s) => s.$2 == _status);
    if (idx >= 0 && idx < steps.length - 1) return steps[idx + 1].$2;
    return _GS.delivered;
  }

  // CTA = the action that ADVANCES INTO the next status.
  String get _ctaLabel => switch (_nextStatus) {
        _GS.driverEnRoute => 'Start — En Route to Customer',
        _GS.driverArrived => 'Arrived at Location',
        _GS.pickedUp      => 'Cylinder Collected',
        _GS.atStation     => 'Arrived at Station',
        _GS.refilling     => 'Start Refilling',
        _GS.returning     => 'Refill Done — Returning',
        _GS.delivered     => 'Mark as Delivered',
        _                 => 'Continue',
      };

  String get _statusLabel => switch (_status) {
        _GS.driverAssigned => 'Order Assigned',
        _GS.driverEnRoute  => 'En Route to Customer',
        _GS.driverArrived  => 'At Customer Location',
        _GS.pickedUp       => 'Cylinder Collected',
        _GS.atStation      => 'At Refill Station',
        _GS.refilling      => 'Refilling in Progress',
        _GS.returning      => 'Returning to Customer',
        _GS.delivered      => 'Delivered',
        _                  => 'In Progress',
      };

  Future<void> _advanceStatus() async {
    if (_isUpdating) return;
    if (_status == _GS.delivered) {
      Navigator.popUntil(context, (r) => r.isFirst);
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() => _isUpdating = true);

    try {
      final next = _nextStatus;
      final data = <String, dynamic>{
        'status':    next,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (next == _GS.pickedUp) {
        data['pickupCompletedAt'] = FieldValue.serverTimestamp();
      } else if (next == _GS.delivered) {
        // OTP verification before marking delivered
        final storedOtp = _order?['deliveryOtp'] as String?;
        if (storedOtp != null && storedOtp.isNotEmpty) {
          final enteredOtp = await _showOtpDialog();
          if (enteredOtp == null) {
            setState(() => _isUpdating = false);
            return;
          }
          if (enteredOtp != storedOtp) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('Incorrect OTP. Ask the customer for the correct code.'),
                backgroundColor: Color(0xFFDC2626),
              ));
            }
            setState(() => _isUpdating = false);
            return;
          }
          data['otpSubmitted'] = enteredOtp;
          data['otpVerifiedAt'] = FieldValue.serverTimestamp();
        }
        data['deliveredAt'] = FieldValue.serverTimestamp();
        data['actualFare']  = _order?['totalPrice'];
        // CF onGasOrderCompleted handles wallet + driver credit
      }

      await _db.collection('gas_orders').doc(widget.orderId).update(data);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content:         Text('Failed to update: $e'),
          backgroundColor: AppColors.errorColor,
        ));
      }
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
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
              'Ask the customer for their 4-digit OTP to confirm gas delivery.',
              style: TextStyle(fontSize: 13, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            TextField(
              controller:   ctrl,
              keyboardType: TextInputType.number,
              maxLength:    4,
              textAlign:    TextAlign.center,
              style: const TextStyle(
                fontSize:   28,
                fontWeight: FontWeight.w900,
                letterSpacing: 8,
              ),
              decoration: InputDecoration(
                hintText:    '0000',
                counterText: '',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: Color(0xFF16A34A)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                      color: Color(0xFF16A34A), width: 2),
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

  Future<void> _cancelOrder() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title:   const Text('Cancel Gas Order?'),
        content: const Text('Are you sure? This may affect your rating.'),
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

    await _db.collection('gas_orders').doc(widget.orderId).update({
      'status':       _GS.cancelled,
      'cancelledAt':  FieldValue.serverTimestamp(),
      'cancelReason': 'Cancelled by driver',
    });

    if (mounted) Navigator.popUntil(context, (r) => r.isFirst);
  }

  LatLng? get _deliveryLatLng {
    final loc = _order?['deliveryLocation'] as GeoPoint?;
    return loc == null ? null : LatLng(loc.latitude, loc.longitude);
  }

  Future<void> _navigateToCustomer() async {
    final dest = _deliveryLatLng;
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


  Future<void> _callCustomer() async {
    final passengerId = _order?['passengerId'] as String?;
    if (passengerId == null) return;

    final userDoc = await _db.collection('users').doc(passengerId).get();
    final phone   = userDoc.data()?['phoneNumber'] as String?;
    if (phone == null) return;

    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
          body: Center(child: CircularProgressIndicator()));
    }

    if (_status == _GS.delivered) {
      return _GasCompletedScreen(
        fare:   (_order?['totalPrice'] as num?)?.toDouble() ?? 0,
        onDone: () => Navigator.popUntil(context, (r) => r.isFirst),
      );
    }

    final deliveryAddress = _order?['deliveryAddress'] as String? ?? '—';
    final cylinderSize    = _order?['cylinderSize']    as String? ?? '—';
    final quantity        = _order?['quantity']         as int?    ?? 1;
    final refillType      = _order?['refillType']       as String? ?? '—';
    final totalPrice      = (_order?['totalPrice']      as num?)?.toDouble() ?? 0;

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title:           Text(_statusLabel),
        backgroundColor: AppTheme.surface,
        actions: [
          IconButton(
            icon:    const Icon(Icons.phone_rounded),
            onPressed: _callCustomer,
            tooltip: 'Call customer',
          ),
        ],
      ),
      body: Column(
        children: [
          _GasStepBar(status: _status, refillType: _refillType),

          // Map area — real GoogleMap + Navigate
          SizedBox(
            height: 200,
            child: Stack(
              children: [
                if (_deliveryLatLng != null)
                  GoogleMap(
                    onMapCreated: (c) => _mapController = c,
                    initialCameraPosition:
                        CameraPosition(target: _deliveryLatLng!, zoom: 14),
                   markers: {
                      Marker(
                        markerId: const MarkerId('delivery'),
                        position: _deliveryLatLng!,
                        icon: MarkerService.instance.pickup(),
                        anchor: const Offset(0.5, 1.0),
                        infoWindow: const InfoWindow(title: 'Customer'),
                      ),
                      if (_driverPos != null)
                        Marker(
                          markerId: const MarkerId('driver'),
                          position: _driverPos!,
                          icon: MarkerService.instance.vehicle('gas'),
                          anchor: const Offset(0.5, 0.5),
                          flat: true,
                          infoWindow: const InfoWindow(title: 'You'),
                        ),
                    },
                    myLocationButtonEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
                    compassEnabled: false,
                  )
                else
                  Container(color: AppTheme.surface),
                Positioned(
                  right: 12, bottom: 12,
                  child: FloatingActionButton.extended(
                    heroTag: 'gasNav',
                    onPressed: _navigateToCustomer,
                    backgroundColor: Colors.orange,
                    icon: const Icon(Icons.navigation_rounded, size: 18),
                    label: const Text('Navigate'),
                  ),
                ),
              ],
            ),
          ),

          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Order details card
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color:        AppTheme.cardBackground,
                      borderRadius: BorderRadius.circular(16),
                      border:       Border.all(color: AppTheme.divider),
                    ),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              width: 44, height: 44,
                              decoration: BoxDecoration(
                                color:        Colors.orange.withValues(
                                    alpha: 0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                  Icons.local_fire_department_rounded,
                                  color: Colors.orange,
                                  size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '$cylinderSize × $quantity',
                                    style: const TextStyle(
                                      fontSize:   16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  Text(
                                    refillType,
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color:    AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              'GH₵ ${totalPrice.toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize:   18,
                                fontWeight: FontWeight.w800,
                                color:      AppTheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const Divider(height: 20),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 16, color: Colors.orange),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                deliveryAddress,
                                style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // CTA
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isUpdating ? null : _advanceStatus,
                      icon: _isUpdating
                          ? const SizedBox(
                              width: 18, height: 18,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white))
                          : const Icon(
                              Icons.local_fire_department_rounded),
                      label: Text(_ctaLabel),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.orange,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  if (_status == _GS.driverAssigned ||
                      _status == _GS.driverEnRoute) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton(
                        onPressed: _cancelOrder,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          padding:
                              const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text('Cancel Order'),
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
    );
  }
}

class _GasStepBar extends StatelessWidget {
  final String status;
  const _GasStepBar({required this.status, required this.refillType});

  final String refillType;

  List<(String, String)> get _steps =>
      _ActiveGasOrderScreenState.stepsFor(refillType);

  int get _currentStep {
    final idx = _steps.indexWhere((s) => s.$2 == status);
    return idx >= 0 ? idx : 0;
  }

  @override
  Widget build(BuildContext context) => Container(
        color:   AppTheme.surface,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: List.generate(_steps.length * 2 - 1, (i) {
            if (i.isOdd) {
              final stepIdx = (i - 1) ~/ 2;
              return Expanded(
                child: Container(
                  height: 2,
                  color: stepIdx < _currentStep
                      ? Colors.orange
                      : AppTheme.divider,
                ),
              );
            }
            final stepIdx = i ~/ 2;
            final done   = stepIdx < _currentStep;
            final active = stepIdx == _currentStep;
            return Column(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: done
                        ? Colors.orange
                        : active
                            ? Colors.orange.withValues(alpha: 0.2)
                            : AppTheme.divider,
                    border: active
                        ? Border.all(color: Colors.orange, width: 2)
                        : null,
                  ),
                  child: Icon(
                    done ? Icons.check_rounded : Icons.circle,
                    size:  done ? 14 : 8,
                    color: done
                        ? Colors.white
                        : active
                            ? Colors.orange
                            : AppTheme.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  _steps[stepIdx].$1,
                  style: TextStyle(
                    fontSize:   9,
                    fontWeight: active || done
                        ? FontWeight.w700
                        : FontWeight.w400,
                    color: active || done
                        ? Colors.orange
                        : AppTheme.textSecondary,
                  ),
                ),
              ],
            );
          }),
        ),
      );
}

class _GasCompletedScreen extends StatelessWidget {
  final double       fare;
  final VoidCallback onDone;
  const _GasCompletedScreen({required this.fare, required this.onDone});

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
                    width: 100, height: 100,
                    decoration: BoxDecoration(
                      color:  Colors.orange.withValues(alpha: 0.15),
                      shape:  BoxShape.circle,
                    ),
                    child: const Icon(
                        Icons.local_fire_department_rounded,
                        size:  50,
                        color: Colors.orange),
                  ),
                  const SizedBox(height: 24),
                  const Text('Gas Delivered!',
                      style: TextStyle(
                          fontSize: 24, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  const Text(
                    'Gas cylinder delivered successfully.\nEarnings added to your wallet.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 15, color: AppTheme.textSecondary),
                  ),
                  const SizedBox(height: 28),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color:        Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                          color: Colors.orange.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        const Text('You earned',
                            style: TextStyle(
                                color: Colors.orange, fontSize: 14)),
                        const SizedBox(height: 4),
                        Text(
                          'GH₵ ${fare.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontSize:   36,
                            fontWeight: FontWeight.w900,
                            color:      Colors.orange,
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
                        backgroundColor: Colors.orange,
                        padding:
                            const EdgeInsets.symmetric(vertical: 16),
                      ),
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