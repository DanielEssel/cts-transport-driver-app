// lib/features/jobs/screens/active_delivery_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cts_transport_driver_app/core/services/marker_service.dart';
import 'package:cts_transport_driver_app/core/services/location/driver_location_publisher.dart';

import '../../../core/constants/app_colors.dart';
import '../../trips/widgets/navigation_button.dart' show openExternalNavigation;
import '../domain/driver_job_cancellation.dart';
import '../data/completion_code_service.dart';
import '../domain/job_stage_plan.dart';
import '../widgets/job_map_layout.dart';
import '../widgets/job_stage_panel.dart';
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
  static const cancelledByDriver = 'cancelledByDriver';

  // Stages a driver may cancel from (unchanged rule: any stage before the
  // delivery is finished).
  static const cancellable = {
    driverAssigned,
    pickupEnroute,
    arrivedAtPickup,
    packagePicked,
    deliveryEnroute,
    arrivedAtDropoff,
  };
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
  double _driverHeading = 0;
  bool _isLoading = true;
  bool _isUpdating = false;

  StreamSubscription<DocumentSnapshot>? _deliverySub;

  // Location is published by the shared DriverLocationPublisher (one GPS
  // stream, foreground service, survives leaving this screen); the screen
  // only reads it for its own map marker.
  final _publisher = DriverLocationPublisher.instance;
  late final _thisJob = ActiveJobRef(ActiveJobKind.delivery, widget.deliveryId);
  String? _shownProblem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await MarkerService.instance.warmUp(context);
      if (mounted) setState(() {});
    });
    _subscribeToDelivery();
    _startLocationSharing();
  }

  @override
  void dispose() {
    _deliverySub?.cancel();
    // Deliberately NOT stopping the publisher: sharing continues while the
    // driver navigates elsewhere, and stops by itself when the delivery ends.
    _publisher.position.removeListener(_onPosition);
    _publisher.problem.removeListener(_onLocationProblem);
    super.dispose();
  }

  // ── Subscriptions ─────────────────────────────────────────────────────────

  void _subscribeToDelivery() {
    _deliverySub = _db
        .collection('deliveries')
        .doc(widget.deliveryId)
        .snapshots()
        .listen((doc) async {
      if (!doc.exists || !mounted) return;

      final delivery = doc.data();

      setState(() {
        _delivery = delivery;
        _status = delivery?['status'] as String? ?? _DS.driverAssigned;
        _isLoading = false;
      });

      _fetchRoute();
    });
  }

  /// Starts (or resumes) location sharing for this delivery. Idempotent:
  /// reopening the screen does not open a second GPS stream. The publisher
  /// checks the delivery is assigned to this driver and not finished.
  Future<void> _startLocationSharing() async {
    _publisher.position.addListener(_onPosition);
    _publisher.problem.addListener(_onLocationProblem);
    final refusal =
        await _publisher.startJob(ActiveJobKind.delivery, widget.deliveryId);
    if (!mounted) return;
    if (refusal != null) debugPrint('Delivery location not shared: $refusal');
    _onLocationProblem();
    _onPosition();
  }

  void _onPosition() {
    final pos = _publisher.position.value;
    // Only this delivery's fixes drive this screen's marker.
    if (!mounted || pos == null || _publisher.activeJob != _thisJob) return;
    setState(() {
      _driverPos = LatLng(pos.latitude, pos.longitude);
      if (pos.heading >= 0) _driverHeading = pos.heading;
    });
  }

  /// Tells the driver when their location is not reaching the customer,
  /// once per distinct problem.
  void _onLocationProblem() {
    final problem = _publisher.problem.value;
    if (!mounted || problem == null || problem == _shownProblem) return;
    _shownProblem = problem;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(problem),
      backgroundColor: AppTheme.danger,
      behavior: SnackBarBehavior.floating,
    ));
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
  //
  // The stage, its one status step and its wording come from deliveryPlan,
  // decided only from the stored status. Statuses with nothing left to do
  // (cancelled, unknown) get no step at all.

  // Every order's code is held by the server (completion_code_service.dart).
  bool get _hasOtp => true;

  LatLng? _targetOf(JobStagePlan? plan) => switch (plan?.target) {
        JobTarget.pickup => _pickupLatLng,
        JobTarget.dropoff => _dropoffLatLng,
        _ => null,
      };

  /// Straight-line metres from the latest fix to this stage's target.
  double? get _metresToTarget {
    final target = _targetOf(deliveryPlan(_status));
    final from = _driverPos;
    if (target == null || from == null) return null;
    return distanceMetres(
        from.latitude, from.longitude, target.latitude, target.longitude);
  }

  JobStagePlan? get _plan =>
      deliveryPlan(_status, metresToTarget: _metresToTarget, hasOtp: _hasOtp);

  /// Applies the stage's one status step. Arrival asks "are you there?"
  /// only when the driver seems far away; hand-over keeps the existing OTP
  /// check, or asks for confirmation when the order has no code. The write
  /// re-reads the delivery in a transaction, so a stale screen or a double
  /// tap cannot skip a stage or write over a cancelled delivery.
  Future<void> _advanceStatus() async {
    final plan = _plan;
    if (_isUpdating || plan == null) return;
    final step = plan.step;
    setState(() => _isUpdating = true);

    try {
      final data = <String, dynamic>{
        'updatedAt': FieldValue.serverTimestamp(),
      };

      switch (step.guard) {
        case JobGuard.arrival:
          final atPickup = step.to == _DS.arrivedAtPickup;
          final ok = await confirmArrival(
            context,
            place: atPickup ? 'pickup' : 'drop-off',
            whoIsTold: atPickup ? 'sender' : 'receiver',
            metresToTarget: _metresToTarget,
          );
          if (!ok) return;
        case JobGuard.handOver:
          // The receiver's code is checked by the server, which holds it
          // where this app cannot read it (completion_code_service.dart).
          final enteredOtp = await _showOtpDialog();
          if (enteredOtp == null) return;
          final check = await verifyCompletionCode(
              collection: 'deliveries', orderId: widget.deliveryId, code: enteredOtp);
          if (check.kind == CodeCheck.noCode) {
            // An order from before completion codes: confirm as before.
            if (!mounted) return;
            final ok = await showJobConfirm(
              context,
              title: 'Confirm delivery?',
              message: 'Only confirm once the receiver has the parcel. '
                  'This completes the delivery.',
              confirmLabel: 'Yes, delivered',
              keepLabel: 'Not yet',
            );
            if (!ok) return;
          } else if (check.kind != CodeCheck.ok) {
            _showError(codeCheckMessage(check, who: 'receiver'));
            return;
          }
        case JobGuard.none:
        case JobGuard.start:
        case JobGuard.complete:
          break;
      }

      // Add timestamps for key events (unchanged fields)
      if (step.to == _DS.packagePicked) {
        data['pickedUpAt'] = FieldValue.serverTimestamp();
      } else if (step.to == _DS.completed) {
        data['completedAt'] = FieldValue.serverTimestamp();
        data['actualFare'] = _delivery?['estimatedFare'];
        // CF onDeliveryCompleted handles wallet + driver credit
      }

      HapticFeedback.mediumImpact();
      await applyJobStep(
        _db,
        collection: 'deliveries',
        docId: widget.deliveryId,
        driverUid: _uid,
        from: step.from,
        to: step.to,
        fields: data,
      );
      final done = step.doneMessage;
      if (done != null && mounted) {
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(SnackBar(
            content: Text(done),
            backgroundColor: AppTheme.primaryDeep,
            behavior: SnackBarBehavior.floating,
          ));
      }
    } on JobStepException catch (e) {
      _showError(e.message);
    } catch (e) {
      debugPrint('Delivery step ${step.from} → ${step.to} failed: $e');
      _showError(
          "Couldn't update the delivery. Check your connection and try again.");
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
        content: Text(message),
        backgroundColor: AppColors.errorColor,
        behavior: SnackBarBehavior.floating,
      ));
  }

  bool _isCancelling = false;

  Future<void> _cancelDelivery() async {
    if (_isCancelling) return;
    setState(() => _isCancelling = true);
    try {
      await _cancelDeliveryConfirmed();
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _cancelDeliveryConfirmed() async {
    final confirmed = await showJobConfirm(
      context,
      title: 'Cancel this delivery?',
      message: 'Are you sure? This may affect your acceptance rate.',
      confirmLabel: 'Cancel delivery',
      keepLabel: 'Keep delivery',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    // One transaction: cancel only if this driver still owns an active order.
    // The server frees the driver (currentTripId is server-owned:
    // onDeliveryStatusChanged / onGasOrderStatusChanged / onTripStatusChanged).
    final orderRef = _db.collection('deliveries').doc(widget.deliveryId);
    final DriverCancelDecision decision;
    try {
      decision = await _db.runTransaction<DriverCancelDecision>((tx) async {
        final order = await tx.get(orderRef);
        final d = decideDriverCancellation(
          driverUid: _uid,
          orderId: widget.deliveryId,
          orderExists: order.exists,
          orderDriverId: order.data()?['driverId'],
          orderStatus: order.data()?['status'],
          cancellableStatuses: _DS.cancellable,
          cancelledStatus: _DS.cancelled,
          driverCurrentTripId: null,
        );
        if (d.cancelOrder) {
          tx.update(orderRef, {
            'status': _DS.cancelled,
            'statusReason': _DS.cancelledByDriver,
            'cancelledAt': FieldValue.serverTimestamp(),
            'cancelReason': 'Cancelled by driver',
          });
        }
        return d;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content:
              Text('Could not cancel. Check your connection and try again.'),
          backgroundColor: AppColors.errorColor,
        ));
      }
      return;
    }

    if (!mounted) return;
    switch (decision.outcome) {
      case DriverCancelOutcome.cancelled:
      case DriverCancelOutcome.alreadyCancelled:
        Navigator.popUntil(context, (r) => r.isFirst);
      case DriverCancelOutcome.notAssignedToDriver:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This job is no longer assigned to you.'),
          backgroundColor: AppColors.errorColor,
        ));
        Navigator.popUntil(context, (r) => r.isFirst);
      case DriverCancelOutcome.notCancellable:
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('This job can no longer be cancelled.'),
          backgroundColor: AppColors.errorColor,
        ));
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
              'Ask the recipient for their 4-digit OTP to confirm delivery.',
              style: TextStyle(
                  fontSize: 15, height: 1.4, color: AppTheme.textSecondary),
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
                  borderSide: const BorderSide(color: AppTheme.primary),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide:
                      const BorderSide(color: AppTheme.primary, width: 2),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            style: TextButton.styleFrom(
              foregroundColor: AppTheme.textPrimary,
              minimumSize: const Size(48, 48),
            ),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: FilledButton.styleFrom(
              backgroundColor: AppTheme.primaryDark,
              foregroundColor: AppTheme.onPrimary,
              minimumSize: const Size(48, 48),
            ),
            child: const Text('Verify'),
          ),
        ],
      ),
    );
  }

  Future<void> _callContact() async {
    final isDropoff = [
      _DS.packagePicked,
      _DS.deliveryEnroute,
      _DS.arrivedAtDropoff,
    ].contains(_status);

    final String? phone = isDropoff
        ? (_delivery?['receiverPhone'] as String?)
        : (_delivery?['passengerPhone'] as String?);

    if (phone == null || phone.trim().isEmpty) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No phone number is available for this contact.'),
        ),
      );
      return;
    }

    final uri = Uri(
      scheme: 'tel',
      path: phone.trim(),
    );

    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to open the phone app.'),
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open the phone app.'),
        ),
      );
    }
  }

  LatLng? get _pickupLatLng {
    final loc = _delivery?['pickupLocation'] as GeoPoint?;
    return loc == null ? null : LatLng(loc.latitude, loc.longitude);
  }

  LatLng? get _dropoffLatLng {
    final loc = _delivery?['dropoffLocation'] as GeoPoint?;
    return loc == null ? null : LatLng(loc.latitude, loc.longitude);
  }

  /// Opens Google Maps to this stage's target. Never changes the status.
  void _navigateToTarget() {
    final dest = _targetOf(_plan);
    if (dest != null) openExternalNavigation(dest);
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_status == _DS.completed) {
      final dropoff = _delivery?['dropoffAddress'] as String?;
      final parcel = _delivery?['parcelType'] as String?;
      return JobCompletedScreen(
        title: 'Delivery completed',
        message: 'The package was delivered. Your earnings will appear '
            'in your wallet shortly.',
        amountLabel: 'Delivery fare',
        amount: (_delivery?['estimatedFare'] as num?)?.toDouble() ?? 0,
        details: [
          if (parcel != null && parcel.isNotEmpty) ('Parcel', parcel),
          if (dropoff != null && dropoff.isNotEmpty) ('Delivered to', dropoff),
        ],
        onDone: () => Navigator.popUntil(context, (r) => r.isFirst),
      );
    }

    final plan = _plan;
    if (plan == null) {
      final cancelled = _status == _DS.cancelled ||
          _status == _DS.cancelledByDriver ||
          _status == 'cancelledByPassenger';
      return JobEndedScreen(
        icon: cancelled ? Icons.cancel_rounded : Icons.error_outline_rounded,
        color: cancelled ? AppTheme.warning : AppTheme.danger,
        title:
            cancelled ? 'Delivery cancelled' : "Can't continue this delivery",
        message: cancelled
            ? 'This delivery was cancelled. There is nothing more to do.'
            : 'This delivery has a status this app version does not '
                'recognise ("$_status"). Please update the app or contact '
                'support.',
        onDone: () => Navigator.popUntil(context, (r) => r.isFirst),
      );
    }

    final pickupAddress = _delivery?['pickupAddress'] as String? ?? '—';
    final dropoffAddress = _delivery?['dropoffAddress'] as String? ?? '—';
    final parcelType = _delivery?['parcelType'] as String? ?? 'Package';
    final weightTier = _delivery?['weightTier'] as String? ?? '';
    final isFragile = _delivery?['isFragile'] as bool? ?? false;
    final senderName = _delivery?['passengerName'] as String?;
    final senderPhone = _delivery?['passengerPhone'] as String?;
    final receiverName = _delivery?['receiverName'] as String?;
    final receiverPhone = _delivery?['receiverPhone'] as String?;
    final estimatedFare =
        (_delivery?['estimatedFare'] as num?)?.toDouble() ?? 0;
    final notes = _delivery?['notes'] as String?;

    final isDropoffLeg = [
      _DS.packagePicked,
      _DS.deliveryEnroute,
      _DS.arrivedAtDropoff,
    ].contains(_status);

    return JobMapLayout(
      plan: plan,
      destinationLabel: isDropoffLeg ? 'Drop-off' : 'Pickup',
      destination: isDropoffLeg ? dropoffAddress : pickupAddress,
      onBack: () => Navigator.maybePop(context),
      onCall: _callContact,
      callLabel: isDropoffLeg ? 'Call receiver' : 'Call sender',
      onRecenter: _recenter,
      mapBuilder: (context, padding) =>
          _buildMapArea(isDropoff: isDropoffLeg, padding: padding),
      details: [
        _buildParcelCard(
          parcelType: parcelType,
          weightTier: weightTier,
          isFragile: isFragile,
          senderName: senderName,
          senderPhone: senderPhone,
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
        // Unchanged: this screen offers cancellation only until the driver
        // reaches the pickup.
        if ([_DS.driverAssigned, _DS.pickupEnroute].contains(_status)) ...[
          const SizedBox(height: 8),
          JobCancelLink(
            label: 'Cancel delivery',
            busy: _isCancelling,
            onTap: _cancelDelivery,
          ),
        ],
      ],
      actions: JobStageActions(
        plan: plan,
        busy: _isUpdating,
        onStep: _advanceStatus,
        onNavigate: plan.target == null ? null : _navigateToTarget,
      ),
    );
  }

  /// Frames the driver and this stage's target, or the whole delivery
  /// before the first fix.
  void _recenter() {
    final target = _targetOf(_plan);
    final points = [
      if (_driverPos != null) _driverPos!,
      if (target != null) target,
    ];
    final pickup = _pickupLatLng;
    final dropoff = _dropoffLatLng;
    fitMapTo(
      _mapController,
      points.length > 1
          ? points
          : [
              if (pickup != null) pickup,
              if (dropoff != null) dropoff,
              ...points,
            ],
    );
  }

  Widget _buildMapArea({required bool isDropoff, required EdgeInsets padding}) {
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
                  rotation: _driverHeading,
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
            padding: padding,
          )
        else
          Container(color: AppTheme.surface),
      ],
    );
  }

  Widget _buildParcelCard({
    required String parcelType,
    required String weightTier,
    required bool isFragile,
    required String? senderName,
    required String? senderPhone,
    required String? receiverName,
    required String? receiverPhone,
    required String? notes,
    required bool isAtDropoff,
  }) {
    final contactName = isAtDropoff ? receiverName : senderName;
    final contactPhone = isAtDropoff ? receiverPhone : senderPhone;
    final contactLabel = isAtDropoff ? 'Receiver' : 'Sender';

    return Container(
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
                  color: AppTheme.serviceDeliveryTint,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(Icons.inventory_2_rounded,
                    color: AppTheme.serviceDelivery, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(parcelType,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textPrimary,
                        )),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: [
                        if (weightTier.isNotEmpty)
                          _Chip(
                              label: weightTier.toUpperCase(),
                              color: AppTheme.serviceDelivery,
                              background: AppTheme.serviceDeliveryTint),
                        if (isFragile)
                          const _Chip(
                              label: '⚠ Fragile',
                              color: AppTheme.warningText,
                              background: AppTheme.warningLight),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (contactName != null || contactPhone != null) ...[
            const Divider(height: 20),
            Row(
              children: [
                const Icon(
                  Icons.person_rounded,
                  size: 20,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        contactLabel,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                      if (contactName != null && contactName.isNotEmpty)
                        Text(
                          contactName,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      if (contactPhone != null && contactPhone.isNotEmpty)
                        InkWell(
                          onTap: _callContact,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Text(
                              contactPhone,
                              style: const TextStyle(
                                fontSize: 14.5,
                                color: AppTheme.primaryDark,
                                fontWeight: FontWeight.w600,
                                decoration: TextDecoration.underline,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (contactPhone != null && contactPhone.isNotEmpty)
                  IconButton(
                    onPressed: _callContact,
                    tooltip: 'Call ${contactLabel.toLowerCase()}',
                    icon: const Icon(Icons.phone_rounded, size: 22),
                    style: IconButton.styleFrom(
                      foregroundColor: AppTheme.primaryDark,
                      backgroundColor: AppTheme.primaryLight,
                      minimumSize: const Size(48, 48),
                      side: const BorderSide(color: AppTheme.primarySubtle),
                    ),
                  ),
              ],
            ),
          ],
          if (notes != null && notes.isNotEmpty) ...[
            const Divider(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.warningLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('📝 $notes',
                  style: const TextStyle(
                    fontSize: 14,
                    height: 1.4,
                    color: AppTheme.warningText,
                  )),
            ),
          ],
        ],
      ),
    );
  }

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
              icon: Icons.trip_origin_rounded,
              color: AppTheme.primaryDark,
              label: 'Pickup',
              address: pickupAddress,
            ),
            Padding(
              padding: const EdgeInsets.only(left: 9, top: 2, bottom: 2),
              child: Align(
                alignment: Alignment.centerLeft,
                child:
                    Container(width: 2, height: 14, color: AppTheme.divider),
              ),
            ),
            _RouteRow(
              icon: Icons.location_on_rounded,
              color: AppTheme.danger,
              label: 'Drop-off',
              address: dropoffAddress,
            ),
            const Divider(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Fare',
                    style: TextStyle(
                        fontSize: 15, color: AppTheme.textSecondary)),
                Text(
                  'GH₵ ${fare.toStringAsFixed(2)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                    color: AppTheme.textPrimary,
                    fontFeatures: [FontFeature.tabularFigures()],
                  ),
                ),
              ],
            ),
          ],
        ),
      );
}

// ── Helpers ───────────────────────────────────────────────────────────────────

class _RouteRow extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final String address;
  const _RouteRow({
    required this.icon,
    required this.color,
    required this.label,
    required this.address,
  });

  @override
  Widget build(BuildContext context) => Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label,
                    style: const TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textSecondary)),
                const SizedBox(height: 1),
                Text(address,
                    style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary),
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
  final Color background;
  const _Chip({
    required this.label,
    required this.color,
    required this.background,
  });

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(label,
            style: TextStyle(
                fontSize: 12, fontWeight: FontWeight.w700, color: color)),
      );
}
