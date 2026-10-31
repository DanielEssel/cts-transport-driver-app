// lib/features/jobs/screens/active_gas_order_screen.dart

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

class _GS {
  static const driverAssigned = 'driverAssigned';
  static const driverEnRoute = 'driverEnRoute';
  static const driverArrived = 'driverArrived';
  static const pickedUp = 'pickedUp';
  static const atStation = 'atStation';
  static const refilling = 'refilling';
  static const returning = 'returning';
  static const delivered = 'delivered';
  static const cancelled = 'cancelled';

  // Stages a driver may cancel from (unchanged rule: any stage before the
  // order is delivered).
  static const cancellable = {
    driverAssigned,
    driverEnRoute,
    driverArrived,
    pickedUp,
    atStation,
    refilling,
    returning,
  };
}

class ActiveGasOrderScreen extends StatefulWidget {
  final String orderId;
  const ActiveGasOrderScreen({super.key, required this.orderId});

  @override
  State<ActiveGasOrderScreen> createState() => _ActiveGasOrderScreenState();
}

class _ActiveGasOrderScreenState extends State<ActiveGasOrderScreen> {
  final _db = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser!.uid;

  List<LatLng> _routePoints = [];
  final _routeService = RouteService();

  Map<String, dynamic>? _order;
  String _status = _GS.driverAssigned;
  bool _isLoading = true;
  bool _isUpdating = false;

  GoogleMapController? _mapController;
  LatLng? _driverPos;
  double _driverHeading = 0;

  StreamSubscription<DocumentSnapshot>? _orderSub;

  // Location is published by the shared DriverLocationPublisher (one GPS
  // stream, foreground service, survives leaving this screen); the screen
  // only reads it for its own marker and route.
  final _publisher = DriverLocationPublisher.instance;
  late final _thisJob = ActiveJobRef(ActiveJobKind.gas, widget.orderId);
  String? _shownProblem;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await MarkerService.instance.warmUp(context);
      if (mounted) setState(() {});
    });
    _subscribeToOrder();
    _startLocationSharing();
  }

  @override
  void dispose() {
    _orderSub?.cancel();
    // Deliberately NOT stopping the publisher: sharing continues while the
    // driver navigates elsewhere, and stops by itself when the order ends.
    _publisher.position.removeListener(_onPosition);
    _publisher.problem.removeListener(_onLocationProblem);
    super.dispose();
  }

  void _fetchRoute() {
    final origin = _driverPos;
    final dest = _deliveryLatLng;
    if (origin == null || dest == null || _routePoints.isNotEmpty) return;
    _routeService.getRoute(origin, dest).then((result) {
      if (result != null && mounted) {
        setState(() => _routePoints = result.points);
      }
    });
  }

  void _subscribeToOrder() {
    _orderSub = _db
        .collection('gas_orders')
        .doc(widget.orderId)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || !mounted) return;
      setState(() {
        _order = doc.data();
        _status = _order?['status'] as String? ?? _GS.driverAssigned;
        _isLoading = false;
      });
    });
  }

  /// Starts (or resumes) location sharing for this gas order. Idempotent:
  /// reopening the screen does not open a second GPS stream. The publisher
  /// checks the order is assigned to this driver and not finished.
  Future<void> _startLocationSharing() async {
    _publisher.position.addListener(_onPosition);
    _publisher.problem.addListener(_onLocationProblem);
    final refusal =
        await _publisher.startJob(ActiveJobKind.gas, widget.orderId);
    if (!mounted) return;
    if (refusal != null) debugPrint('Gas location not shared: $refusal');
    _onLocationProblem();
    _onPosition();
  }

  void _onPosition() {
    final pos = _publisher.position.value;
    // Only this order's fixes drive this screen's marker and route.
    if (!mounted || pos == null || _publisher.activeJob != _thisJob) return;
    setState(() {
      _driverPos = LatLng(pos.latitude, pos.longitude);
      if (pos.heading >= 0) _driverHeading = pos.heading;
    });
    _fetchRoute(); // driver → customer route; no-op after the first fetch
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

  // Two flows — must match passenger GasRefillType.steps exactly:
  //  • pickupAndReturn → full round trip
  //  • everything else → simple drop-off
  // The stage, its one status step and its wording come from gasPlan,
  // decided only from the stored status. Statuses with nothing left to do
  // (cancelled, failed, unknown) get no step at all.

  String get _refillType => _order?['refillType'] as String? ?? '';
  // Every order's code is held by the server (completion_code_service.dart).
  bool get _hasOtp => true;

  /// Straight-line metres from the latest fix to the customer, when this
  /// stage heads there.
  double? get _metresToTarget {
    final base = gasPlan(_status, refillType: _refillType);
    final target = base?.target == null ? null : _deliveryLatLng;
    final from = _driverPos;
    if (target == null || from == null) return null;
    return distanceMetres(
        from.latitude, from.longitude, target.latitude, target.longitude);
  }

  JobStagePlan? get _plan => gasPlan(
        _status,
        refillType: _refillType,
        metresToTarget: _metresToTarget,
        hasOtp: _hasOtp,
      );

  /// Applies the stage's one status step. Arrival asks "are you there?"
  /// only when the driver seems far away; hand-over keeps the existing OTP
  /// check, or asks for confirmation when the order has no code. The write
  /// re-reads the order in a transaction, so a stale screen or a double tap
  /// cannot skip a stage or write over a cancelled order.
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
          final ok = await confirmArrival(
            context,
            place: "customer's location",
            whoIsTold: 'customer',
            metresToTarget: _metresToTarget,
          );
          if (!ok) return;
        case JobGuard.handOver:
          // The receiver's code is checked by the server, which holds it
          // where this app cannot read it (completion_code_service.dart).
          final enteredOtp = await _showOtpDialog();
          if (enteredOtp == null) return;
          final check = await verifyCompletionCode(
              collection: 'gas_orders', orderId: widget.orderId, code: enteredOtp);
          if (check.kind == CodeCheck.noCode) {
            // An order from before completion codes: confirm as before.
            if (!mounted) return;
            final ok = await showJobConfirm(
              context,
              title: 'Confirm delivery?',
              message: 'Only confirm once the customer has the gas. '
                  'This completes the order.',
              confirmLabel: 'Yes, delivered',
              keepLabel: 'Not yet',
            );
            if (!ok) return;
          } else if (check.kind != CodeCheck.ok) {
            _showError(codeCheckMessage(check, who: 'customer'));
            return;
          }
        case JobGuard.none:
        case JobGuard.start:
        case JobGuard.complete:
          break;
      }

      // Timestamps for key events (unchanged fields)
      if (step.to == _GS.pickedUp) {
        data['pickupCompletedAt'] = FieldValue.serverTimestamp();
      } else if (step.to == _GS.delivered) {
        data['deliveredAt'] = FieldValue.serverTimestamp();
        data['actualFare'] = _order?['totalPrice'];
        // CF onGasOrderCompleted handles wallet + driver credit
      }

      HapticFeedback.mediumImpact();
      await applyJobStep(
        _db,
        collection: 'gas_orders',
        docId: widget.orderId,
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
      debugPrint('Gas step ${step.from} → ${step.to} failed: $e');
      _showError(
          "Couldn't update the order. Check your connection and try again.");
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

  bool _isCancelling = false;

  Future<void> _cancelOrder() async {
    if (_isCancelling) return;
    setState(() => _isCancelling = true);
    try {
      await _cancelOrderConfirmed();
    } finally {
      if (mounted) setState(() => _isCancelling = false);
    }
  }

  Future<void> _cancelOrderConfirmed() async {
    final confirmed = await showJobConfirm(
      context,
      title: 'Cancel this gas order?',
      message: 'Are you sure? This may affect your rating.',
      confirmLabel: 'Cancel order',
      keepLabel: 'Keep order',
      destructive: true,
    );

    if (!confirmed || !mounted) return;

    // One transaction: cancel only if this driver still owns an active order.
    // The server frees the driver (currentTripId is server-owned:
    // onDeliveryStatusChanged / onGasOrderStatusChanged / onTripStatusChanged).
    final orderRef = _db.collection('gas_orders').doc(widget.orderId);
    final DriverCancelDecision decision;
    try {
      decision = await _db.runTransaction<DriverCancelDecision>((tx) async {
        final order = await tx.get(orderRef);
        final d = decideDriverCancellation(
          driverUid: _uid,
          orderId: widget.orderId,
          orderExists: order.exists,
          orderDriverId: order.data()?['driverId'],
          orderStatus: order.data()?['status'],
          cancellableStatuses: _GS.cancellable,
          cancelledStatus: _GS.cancelled,
          driverCurrentTripId: null,
        );
        if (d.cancelOrder) {
          tx.update(orderRef, {
            'status': _GS.cancelled,
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

  LatLng? get _deliveryLatLng {
    final loc = _order?['deliveryLocation'] as GeoPoint?;
    return loc == null ? null : LatLng(loc.latitude, loc.longitude);
  }

  /// Opens Google Maps to the customer. Never changes the status.
  void _navigateToCustomer() {
    final dest = _deliveryLatLng;
    if (dest != null) openExternalNavigation(dest);
  }

  Future<void> _callCustomer() async {
    final passengerId = _order?['passengerId'] as String?;
    if (passengerId == null) return;

    final userDoc = await _db.collection('users').doc(passengerId).get();
    final phone = userDoc.data()?['phoneNumber'] as String?;
    if (phone == null) return;

    final uri = Uri(scheme: 'tel', path: phone);
    if (await canLaunchUrl(uri)) launchUrl(uri);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTheme.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_status == _GS.delivered) {
      final cylinderSize = _order?['cylinderSize'] as String?;
      final quantity = (_order?['quantity'] as num?)?.toInt() ?? 1;
      final address = _order?['deliveryAddress'] as String?;
      return JobCompletedScreen(
        title: 'Gas delivered',
        message: 'The gas order was delivered. Your earnings will appear '
            'in your wallet shortly.',
        amountLabel: 'Order total',
        amount: (_order?['totalPrice'] as num?)?.toDouble() ?? 0,
        details: [
          if (cylinderSize != null && cylinderSize.isNotEmpty)
            ('Cylinder', '$cylinderSize × $quantity'),
          if (_refillType.isNotEmpty) ('Refill type', _refillType),
          if (address != null && address.isNotEmpty) ('Delivered to', address),
        ],
        onDone: () => Navigator.popUntil(context, (r) => r.isFirst),
      );
    }

    final plan = _plan;
    if (plan == null) {
      final cancelled = _status == _GS.cancelled || _status == 'failed';
      return JobEndedScreen(
        icon: cancelled ? Icons.cancel_rounded : Icons.error_outline_rounded,
        color: cancelled ? AppTheme.warning : AppTheme.danger,
        title: cancelled ? 'Order ended' : "Can't continue this order",
        message: cancelled
            ? 'This gas order was cancelled or could not be completed. '
                'There is nothing more to do.'
            : 'This gas order has a status this screen cannot update '
                '("$_status"). Please update the app or contact support.',
        onDone: () => Navigator.popUntil(context, (r) => r.isFirst),
      );
    }

    final deliveryAddress = _order?['deliveryAddress'] as String? ?? '—';
    final cylinderSize = _order?['cylinderSize'] as String? ?? '—';
    final quantity = _order?['quantity'] as int? ?? 1;
    final refillType = _order?['refillType'] as String? ?? '—';
    final totalPrice = (_order?['totalPrice'] as num?)?.toDouble() ?? 0;

    return JobMapLayout(
      plan: plan,
      destinationLabel: 'Customer',
      destination: deliveryAddress,
      onBack: () => Navigator.maybePop(context),
      onCall: _callCustomer,
      callLabel: 'Call customer',
      onRecenter: _recenter,
      mapBuilder: (context, padding) => _buildMapArea(padding: padding),
      details: [
        // Order details card
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.cardBackground,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppTheme.divider),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppTheme.serviceGasTint,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.propane_tank_rounded,
                        color: AppTheme.serviceGas, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$cylinderSize × $quantity',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          refillType,
                          style: const TextStyle(
                            fontSize: 14,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'GH₵ ${totalPrice.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textPrimary,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24, color: AppTheme.divider),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(Icons.location_on_rounded,
                        size: 20, color: AppTheme.danger),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Customer',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          deliveryAddress,
                          style: const TextStyle(
                            fontSize: 15,
                            height: 1.35,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        // Unchanged: this screen offers cancellation only until the driver
        // reaches the customer.
        if (_status == _GS.driverAssigned || _status == _GS.driverEnRoute) ...[
          const SizedBox(height: 8),
          JobCancelLink(
            label: 'Cancel order',
            busy: _isCancelling,
            onTap: _cancelOrder,
          ),
        ],
      ],
      actions: JobStageActions(
        plan: plan,
        busy: _isUpdating,
        onStep: _advanceStatus,
        onNavigate: plan.target == null ? null : _navigateToCustomer,
      ),
    );
  }

  /// Frames the driver and the customer (just the customer before the
  /// first fix).
  void _recenter() {
    final customer = _deliveryLatLng;
    final driver = _driverPos;
    fitMapTo(_mapController, [
      if (driver != null) driver,
      if (customer != null) customer,
    ]);
  }

  Widget _buildMapArea({required EdgeInsets padding}) {
    return Stack(
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
                  color: AppTheme.serviceGas,
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
}
