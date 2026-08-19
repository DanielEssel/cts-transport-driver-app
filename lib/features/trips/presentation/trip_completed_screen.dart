// lib/features/trips/presentation/trip_completed_screen.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../models/trip_model.dart';

class TripCompletedScreen extends StatefulWidget {
  final String tripId;
  final TripModel trip;

  const TripCompletedScreen({
    super.key,
    required this.tripId,
    required this.trip,
  });

  @override
  State<TripCompletedScreen> createState() => _TripCompletedScreenState();
}

class _TripCompletedScreenState extends State<TripCompletedScreen> {
  static const _green = Color(0xFF16A34A);
  static const _background = Color(0xFFF8FAF9);

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _tripSubscription;

  bool _isLoading = true;
  bool _isSettled = false;

  double _fare = 0.0;
  double _driverEarnings = 0.0;
  double _platformFee = 0.0;

  String _paymentMethod = 'Wallet';

  @override
  void initState() {
    super.initState();
    _startTripListener();
  }

  // ---------------------------------------------------------------------------
  // FIRESTORE
  // ---------------------------------------------------------------------------

  void _startTripListener() {
    final tripRef = _db.collection('trips').doc(widget.tripId);

    _tripSubscription = tripRef.snapshots().listen(
      (snapshot) {
        if (!snapshot.exists || !mounted) {
          return;
        }

        final data = snapshot.data();
        if (data == null) {
          return;
        }

        _updateFromTripData(data);
      },
      onError: (error) {
        debugPrint(
          '❌ TripCompletedScreen listener error: $error',
        );

        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  void _updateFromTripData(Map<String, dynamic> data) {
    /*
     * Backend completion function writes:
     *
     * actualFare
     * platformFee
     * driverEarnings
     * walletProcessed
     * paymentMethod
     * completedAt
     *
     * Do NOT use:
     *
     * finalFare
     * settlementCompletedAt
     *
     * because those are not part of the current backend contract.
     */

    final actualFare = _readDouble(data['actualFare']);

    final platformFee = _readDouble(data['platformFee']);

    final driverEarnings = _readDouble(data['driverEarnings']);

    final paymentMethod =
        (data['paymentMethod'] as String?)?.trim().toLowerCase();

    /*
     * Wallet:
     *   Cloud Function releases escrow and marks walletProcessed=true.
     *
     * Cash:
     *   Cloud Function records the driver's cash earnings and
     *   commission debt.
     *
     * Therefore walletProcessed is still the completion/idempotency
     * signal used by the current backend.
     */
    final walletProcessed = data['walletProcessed'] == true;

    if (!mounted) return;

    setState(() {
      _fare = actualFare > 0 ? actualFare : _fare;
      _platformFee = platformFee;
      _driverEarnings = driverEarnings;
      _paymentMethod = _formatPaymentMethod(paymentMethod);
      _isSettled = walletProcessed;
      _isLoading = false;
    });
  }

  double _readDouble(dynamic value) {
    if (value is num) {
      return value.toDouble();
    }

    return 0.0;
  }

  String _formatPaymentMethod(String? method) {
    switch (method) {
      case 'cash':
        return 'Cash';

      case 'wallet':
        return 'Wallet';

      case 'card':
        return 'Card';

      case 'momo':
        return 'Mobile Money';

      default:
        return method == null || method.isEmpty
            ? 'Wallet'
            : '${method[0].toUpperCase()}${method.substring(1)}';
    }
  }

  // ---------------------------------------------------------------------------
  // NAVIGATION
  // ---------------------------------------------------------------------------

  void _handleDone() {
    /*
     * IMPORTANT:
     *
     * Do not push '/driver-shell' here.
     *
     * Your current driver-shell route requires a DriverProfile.
     * Pushing it without that profile causes:
     *
     *   driverShell requires DriverProfile, got: Null
     *
     * TripFlowScreen owns this trip-state flow, so simply pop the
     * completion screen and let the existing navigation hierarchy
     * handle returning to the driver experience.
     */
    if (!mounted) return;

    Navigator.of(context).pop();
  }

  // ---------------------------------------------------------------------------
  // LIFECYCLE
  // ---------------------------------------------------------------------------

  @override
  void dispose() {
    _tripSubscription?.cancel();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const _SettlementLoadingScreen();
    }

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      const SizedBox(height: 30),

                      _buildSuccessIcon(),

                      const SizedBox(height: 24),

                      const Text(
                        'Trip Completed!',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 25,
                          fontWeight: FontWeight.w800,
                          color: _green,
                          letterSpacing: -0.4,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        _isSettled
                            ? 'Your trip has been settled successfully.'
                            : 'Your trip is complete. Settlement is being processed.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: Colors.grey[600],
                        ),
                      ),

                      const SizedBox(height: 30),

                      _buildFareCard(),

                      const SizedBox(height: 20),

                      if (!_isSettled) _buildProcessingCard(),

                      if (_isSettled) _buildSettledCard(),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              _buildDoneButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSuccessIcon() {
    return Container(
      width: 86,
      height: 86,
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.10),
        shape: BoxShape.circle,
      ),
      child: Container(
        margin: const EdgeInsets.all(9),
        decoration: BoxDecoration(
          color: _green.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.check_rounded,
          color: _green,
          size: 48,
        ),
      ),
    );
  }

  Widget _buildFareCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.black.withValues(alpha: 0.04),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.045),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _buildInfoRow(
            label: 'Trip Fare',
            value: 'GHS ${_fare.toStringAsFixed(2)}',
            valueColor: Colors.orange[700]!,
          ),

          const Divider(height: 26),

          _buildInfoRow(
            label: 'Driver Earnings',
            value: _driverEarnings > 0
                ? 'GHS ${_driverEarnings.toStringAsFixed(2)}'
                : _isSettled
                    ? 'GHS 0.00'
                    : 'Processing...',
            valueColor: _green,
          ),

          const Divider(height: 26),

          _buildInfoRow(
            label: 'Payment',
            value: _paymentMethod,
            valueColor: Colors.blue[700]!,
          ),

          if (_platformFee > 0) ...[
            const Divider(height: 26),
            _buildInfoRow(
              label: 'Platform Fee',
              value: 'GHS ${_platformFee.toStringAsFixed(2)}',
              valueColor: Colors.grey[700]!,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildProcessingCard() {
    final isCash = _paymentMethod.toLowerCase() == 'cash';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.orange[50],
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: Colors.orange[200]!,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 21,
            height: 21,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.orange[700],
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Text(
              isCash
                  ? 'Your trip is complete. Final earnings and commission processing are being confirmed.'
                  : 'Your trip is complete. Your wallet settlement is being processed.',
              style: TextStyle(
                fontSize: 13,
                height: 1.4,
                color: Colors.orange[800],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettledCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 14,
      ),
      decoration: BoxDecoration(
        color: _green.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: _green.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.verified_rounded,
            color: _green,
            size: 21,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: Text(
              _paymentMethod.toLowerCase() == 'cash'
                  ? 'Trip recorded successfully.'
                  : 'Wallet settlement completed successfully.',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: _green,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDoneButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: _handleDone,
        style: FilledButton.styleFrom(
          backgroundColor: _green,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 16),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        child: const Text(
          'Done',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    required Color valueColor,
  }) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
        ),

        const SizedBox(width: 16),

        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: valueColor,
            ),
          ),
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// LOADING SCREEN
// -----------------------------------------------------------------------------

class _SettlementLoadingScreen extends StatelessWidget {
  const _SettlementLoadingScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF8FAF9),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF16A34A),
            ),
            SizedBox(height: 24),
            Text(
              'Loading trip details...',
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey,
              ),
            ),
          ],
        ),
      ),
    );
  }
}