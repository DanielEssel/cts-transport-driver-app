// lib/features/trips/presentation/trip_completed_screen.dart

import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../app/app_theme.dart';
import '../../jobs/widgets/job_stage_panel.dart';
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

    final isCash = _paymentMethod.toLowerCase() == 'cash';

    return Scaffold(
      backgroundColor: AppTheme.background,
      // Same pinned primary action as the delivery and gas completed screens.
      // It still only closes this screen.
      bottomNavigationBar: JobFooterButton(
        buttonKey: const ValueKey('trip-completed-done'),
        label: 'Done',
        icon: Icons.check_rounded,
        onPressed: _handleDone,
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                JobOutcomeHeader(
                  icon: Icons.check_rounded,
                  color: AppTheme.primaryDark,
                  title: 'Trip Completed!',
                  message: _isSettled
                      ? 'Your trip has been settled successfully.'
                      : 'Your trip is complete. Settlement is being processed.',
                ),
                const SizedBox(height: 28),
                _buildFareCard(),
                const SizedBox(height: 16),
                if (!_isSettled) _buildProcessingCard(isCash),
                if (_isSettled) _buildSettledCard(isCash),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Earnings first (what the driver cares about), then the trip figures.
  Widget _buildFareCard() {
    final earnings = _driverEarnings > 0
        ? 'GHS ${_driverEarnings.toStringAsFixed(2)}'
        : _isSettled
            ? 'GHS 0.00'
            : 'Processing...';

    return JobSummaryCard(
      children: [
        const Text(
          'DRIVER EARNINGS',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 0.8,
            color: AppTheme.textSecondary,
          ),
        ),
        const SizedBox(height: 6),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            earnings,
            style: TextStyle(
              fontSize: _driverEarnings > 0 || _isSettled ? 34 : 24,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
              color: _driverEarnings > 0 || _isSettled
                  ? AppTheme.primaryDark
                  : AppTheme.textSecondary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const Divider(height: 28, color: AppTheme.divider),
        JobSummaryRow(
          label: 'Trip Fare',
          value: 'GHS ${_fare.toStringAsFixed(2)}',
        ),
        const Divider(height: 28, color: AppTheme.divider),
        JobSummaryRow(label: 'Payment', value: _paymentMethod),
        if (_platformFee > 0) ...[
          const Divider(height: 28, color: AppTheme.divider),
          JobSummaryRow(
            label: 'Platform Fee',
            value: 'GHS ${_platformFee.toStringAsFixed(2)}',
          ),
        ],
      ],
    );
  }

  Widget _buildProcessingCard(bool isCash) {
    return _StatusNote(
      background: AppTheme.warningLight,
      border: const Color(0xFFFDE68A),
      foreground: AppTheme.warningText,
      leading: const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: AppTheme.warningText,
        ),
      ),
      text: isCash
          ? 'Your trip is complete. Final earnings and commission processing are being confirmed.'
          : 'Your trip is complete. Your wallet settlement is being processed.',
    );
  }

  Widget _buildSettledCard(bool isCash) {
    return _StatusNote(
      background: AppTheme.primaryLight,
      border: AppTheme.primarySubtle,
      foreground: AppTheme.primaryDeep,
      leading: const Icon(
        Icons.verified_rounded,
        color: AppTheme.primaryDark,
        size: 22,
      ),
      text: isCash
          ? 'Trip recorded successfully.'
          : 'Wallet settlement completed successfully.',
    );
  }
}

/// A one-line status under the figures: settlement pending or done.
class _StatusNote extends StatelessWidget {
  final Color background;
  final Color border;
  final Color foreground;
  final Widget leading;
  final String text;

  const _StatusNote({
    required this.background,
    required this.border,
    required this.foreground,
    required this.leading,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          leading,
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                height: 1.4,
                fontWeight: FontWeight.w600,
                color: foreground,
              ),
            ),
          ),
        ],
      ),
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
      backgroundColor: AppTheme.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 24),
            Text(
              'Loading trip details...',
              style: TextStyle(
                fontSize: 15,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
