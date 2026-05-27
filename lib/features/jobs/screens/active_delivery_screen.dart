// lib/features/jobs/screens/active_delivery_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/constants/app_colors.dart';
import '../../../app/app_theme.dart';

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

  Map<String, dynamic>? _delivery;
  String _status = _DS.driverAssigned;
  bool _isLoading = true;
  bool _isUpdating = false;

  StreamSubscription<DocumentSnapshot>? _deliverySub;
  StreamSubscription<Position>? _locationSub;

  @override
  void initState() {
    super.initState();
    _subscribeToDelivery();
    _startLocationUpdates();
  }

  @override
  void dispose() {
    _deliverySub?.cancel();
    _locationSub?.cancel();
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
    });
  }

  void _startLocationUpdates() {
    _locationSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 15,
      ),
    ).listen((pos) async {
      await _db.collection('deliveries').doc(widget.deliveryId).update({
        'driverCurrentLocation': GeoPoint(pos.latitude, pos.longitude),
        'driverLocationUpdatedAt': FieldValue.serverTimestamp(),
      });
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
                content: Text('Incorrect OTP. Ask the recipient for the correct code.'),
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
        data['actualFare']  = _delivery?['estimatedFare'];
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
                hintText:     '0000',
                counterText:  '',
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

  Future<void> _updateDriverEarnings() async {
    final fare = (_delivery?['estimatedFare'] as num?)?.toDouble() ?? 0;
    if (fare <= 0) return;

    await _db.collection('drivers').doc(_uid).update({
      'totalEarnings': FieldValue.increment(fare),
      'totalDeliveries': FieldValue.increment(1),
      'todayEarnings': FieldValue.increment(fare), // ← ADD
      'todayTrips': FieldValue.increment(1), // ← ADD
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await _db.collection('drivers').doc(_uid).collection('earnings').add({
      'amount': fare,
      'type': 'delivery',
      'referenceId': widget.deliveryId,
      'createdAt': FieldValue.serverTimestamp(),
    });
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

    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: AppBar(
        title: Text(_statusLabel),
        backgroundColor: AppTheme.surface,
        actions: [
          IconButton(
            icon: const Icon(Icons.phone_rounded),
            onPressed: _callContact,
            tooltip: isAtPickup ? 'Call sender' : 'Call receiver',
          ),
        ],
      ),
      body: Column(
        children: [
          // ── Progress bar ──
          _DeliveryStepBar(status: _status),

          // ── Map placeholder ──
          _buildMapArea(
            isDropoff:
                [_DS.deliveryEnroute, _DS.arrivedAtDropoff].contains(_status),
            address:
                [_DS.deliveryEnroute, _DS.arrivedAtDropoff].contains(_status)
                    ? dropoffAddress
                    : pickupAddress,
          ),

          // ── Scrollable content ──
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Parcel card
                  _buildParcelCard(
                    parcelType: parcelType,
                    weightTier: weightTier,
                    isFragile: isFragile,
                    receiverName: receiverName,
                    receiverPhone: receiverPhone,
                    notes: notes,
                    isAtDropoff: [
                      _DS.deliveryEnroute,
                      _DS.arrivedAtDropoff,
                    ].contains(_status),
                  ),
                  const SizedBox(height: 12),

                  // Route card
                  _buildRouteCard(
                    pickupAddress: pickupAddress,
                    dropoffAddress: dropoffAddress,
                    fare: estimatedFare,
                  ),
                  const SizedBox(height: 20),

                  // CTA
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
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),

                  // Cancel button — only before pickup
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
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

  Widget _buildMapArea({required bool isDropoff, required String address}) =>
      Container(
        height: 150,
        width: double.infinity,
        color: AppTheme.primaryLight.withValues(alpha: 0.2),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                isDropoff
                    ? Icons.local_shipping_rounded
                    : Icons.inventory_2_rounded,
                size: 36,
                color: AppTheme.primary,
              ),
              const SizedBox(height: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: AppTheme.primary,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  address,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      );

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
