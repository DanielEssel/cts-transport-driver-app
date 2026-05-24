// lib/features/driver/presentation/driver_pending_screen.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/constants/app_text_styles.dart';
import '../../../../app/app_routes.dart';

class DriverPendingScreen extends StatefulWidget {
  const DriverPendingScreen({super.key});

  @override
  State<DriverPendingScreen> createState() => _DriverPendingScreenState();
}

class _DriverPendingScreenState extends State<DriverPendingScreen> {
  final _db  = FirebaseFirestore.instance;
  final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  StreamSubscription<DocumentSnapshot>? _sub;

  bool      _isApproved       = false;
  bool      _isRejected       = false;
  DateTime? _submittedAt;
  DateTime? _approvedAt;
  Map<String, dynamic> _documents = {};
  bool      _loading          = true;

  @override
  void initState() {
    super.initState();
    _subscribeToDriver();
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _subscribeToDriver() {
    _sub = _db
        .collection('drivers')
        .doc(_uid)
        .snapshots()
        .listen((doc) {
      if (!doc.exists || !mounted) return;
      final data = doc.data()!;

      final wasApproved = _isApproved;
      final isApproved  = data['isApproved'] as bool? ?? false;
      final isRejected  = data['documentsRejected'] as bool? ?? false;

      setState(() {
        _isApproved  = isApproved;
        _isRejected  = isRejected;
        _submittedAt = (data['submittedForReviewAt'] as Timestamp?)?.toDate();
        _approvedAt  = (data['approvedAt']           as Timestamp?)?.toDate();
        _documents   = data['documents'] as Map<String, dynamic>? ?? {};
        _loading     = false;
      });

      // Auto-navigate when approved
      if (!wasApproved && isApproved && mounted) {
        _onApproved();
      }
    });
  }

  void _onApproved() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color:        AppColors.primaryDim,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.verified_rounded,
                  color: AppColors.primary, size: 40),
            ),
            const SizedBox(height: 16),
            const Text('Account Approved! 🎉',
                style: TextStyle(
                  fontSize:   20,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Your account has been verified. '
              'You can now start accepting rides and deliveries.',
              textAlign: TextAlign.center,
              style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textSecondary),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.driverPhone,
                  (_) => false,
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
                child: const Text('Start Driving',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color:      Colors.white,
                    )),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Rejected documents ────────────────────────────────────────────────────

  List<String> get _rejectedDocs {
    final rejected = <String>[];
    _documents.forEach((key, value) {
      if (value is Map && value['status'] == 'rejected') {
        rejected.add(key);
      }
    });
    return rejected;
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
              horizontal: 24, vertical: 20),
          child: Column(
            children: [
              const SizedBox(height: 40),

              // ── Icon ──
              Container(
                width: 120, height: 120,
                decoration: BoxDecoration(
                  color:  AppColors.primary.withValues(alpha: 0.08),
                  shape:  BoxShape.circle,
                ),
                child: Icon(
                  _isApproved
                      ? Icons.verified_rounded
                      : _isRejected
                          ? Icons.error_outline_rounded
                          : Icons.history_toggle_off_rounded,
                  size:  64,
                  color: _isApproved
                      ? AppColors.primary
                      : _isRejected
                          ? AppColors.error
                          : AppColors.primary,
                ),
              ),

              const SizedBox(height: 32),

              // ── Title ──
              Text(
                _isApproved
                    ? 'Account Approved!'
                    : _isRejected
                        ? 'Documents Rejected'
                        : 'Verification Pending',
                style: AppTextStyles.display,
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 12),

              Text(
                _isApproved
                    ? 'Your account is verified. Tap below to start driving.'
                    : _isRejected
                        ? 'Some documents were rejected. Please re-upload and resubmit.'
                        : 'We\'ve received your documents. Our team is reviewing them — this usually takes 24 hours.',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodySmall
                    .copyWith(color: AppColors.textSecondary),
              ),

              const SizedBox(height: 40),

              // ── Timeline ──
              _Timeline(
                submittedAt: _submittedAt,
                approvedAt:  _approvedAt,
                isApproved:  _isApproved,
                isRejected:  _isRejected,
              ),

              // ── Rejected docs list ──
              if (_isRejected && _rejectedDocs.isNotEmpty) ...[
                const SizedBox(height: 24),
                Container(
                  width:   double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color:        AppColors.errorLight,
                    borderRadius: BorderRadius.circular(14),
                    border:       Border.all(
                        color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.warning_rounded,
                              color: AppColors.error, size: 16),
                          SizedBox(width: 8),
                          Text('Documents requiring re-upload',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                color:      AppColors.error,
                                fontSize:   13,
                              )),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._rejectedDocs.map((key) {
                        final reason = (_documents[key]
                                as Map?)?['rejectionReason']
                            as String?;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.circle,
                                  size: 6,
                                  color: AppColors.error),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _docLabel(key),
                                      style: AppTextStyles.labelMedium
                                          .copyWith(
                                              color: AppColors.error),
                                    ),
                                    if (reason != null)
                                      Text(reason,
                                          style: AppTextStyles.caption
                                              .copyWith(
                                                  color: AppColors
                                                      .textSecondary)),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32),

              // ── Support card ──
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color:        AppColors.surfaceAlt,
                  borderRadius: BorderRadius.circular(16),
                  border:       Border.all(color: AppColors.border),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.support_agent_rounded,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Need help?',
                              style: AppTextStyles.labelLarge
                                  .copyWith(fontSize: 13)),
                          const SizedBox(height: 2),
                          Text(
                            'Contact support if your review takes longer than 24 hours.',
                            style: AppTextStyles.caption.copyWith(
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // ── CTA ──
              if (_isApproved)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () =>
                        Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.driverPhone,
                      (_) => false,
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Start Driving',
                        style: TextStyle(
                          fontSize:   15,
                          fontWeight: FontWeight.w700,
                          color:      Colors.white,
                        )),
                  ),
                )
              else if (_isRejected)
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.pushNamed(
                        context, AppRoutes.driverDocuments),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.error,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: const Text('Re-upload Documents',
                        style: TextStyle(
                          fontSize:   15,
                          fontWeight: FontWeight.w700,
                          color:      Colors.white,
                        )),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () =>
                        Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.login,
                      (_) => false,
                    ),
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      side: const BorderSide(color: AppColors.border),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14)),
                    ),
                    child: Text('Return to Login',
                        style: AppTextStyles.labelLarge
                            .copyWith(color: AppColors.textPrimary)),
                  ),
                ),

              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  String _docLabel(String key) {
    const labels = {
      'profile_photo':         'Profile Photo',
      'national_id':           'National ID / Passport',
      'drivers_license':       "Driver's License",
      'vehicle_registration':  'Vehicle Registration',
      'roadworthy_certificate':'Roadworthy Certificate',
      'insurance':             'Vehicle Insurance',
      'police_clearance':      'Police Clearance',
      'vehicle_photo_front':   'Vehicle Photo (Front)',
      'vehicle_photo_side':    'Vehicle Photo (Side)',
    };
    return labels[key] ?? key;
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// TIMELINE WIDGET
// ─────────────────────────────────────────────────────────────────────────────

class _Timeline extends StatelessWidget {
  final DateTime? submittedAt;
  final DateTime? approvedAt;
  final bool      isApproved;
  final bool      isRejected;

  const _Timeline({
    required this.submittedAt,
    required this.approvedAt,
    required this.isApproved,
    required this.isRejected,
  });

  String _fmt(DateTime? dt) {
    if (dt == null) return '—';
    return DateFormat('MMM d, h:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _Step(
          title:       'Documents Submitted',
          time:        submittedAt != null ? _fmt(submittedAt) : 'Just now',
          isCompleted: true,
          isLast:      false,
        ),
        _Step(
          title:       isRejected ? 'Review Complete' : 'Under Review',
          time:        isApproved || isRejected
              ? _fmt(approvedAt)
              : 'Usually within 24 hours',
          isCompleted: isApproved || isRejected,
          isCurrent:   !isApproved && !isRejected,
          isError:     isRejected,
          isLast:      false,
        ),
        _Step(
          title:       'Account Activated',
          time:        isApproved ? _fmt(approvedAt) : 'Final Step',
          isCompleted: isApproved,
          isCurrent:   false,
          isLast:      true,
        ),
      ],
    );
  }
}

class _Step extends StatelessWidget {
  final String title;
  final String time;
  final bool   isCompleted;
  final bool   isCurrent;
  final bool   isError;
  final bool   isLast;

  const _Step({
    required this.title,
    required this.time,
    required this.isCompleted,
    this.isCurrent = false,
    this.isError   = false,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    final color = isError
        ? AppColors.error
        : isCompleted
            ? AppColors.success
            : isCurrent
                ? AppColors.primary
                : AppColors.border;

    return SizedBox(
      height: 64,
      child: Row(
        children: [
          Column(
            children: [
              Icon(
                isError
                    ? Icons.cancel_rounded
                    : isCompleted
                        ? Icons.check_circle_rounded
                        : isCurrent
                            ? Icons.radio_button_checked_rounded
                            : Icons.circle_outlined,
                color: color,
                size:  22,
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 2,
                    color: isCompleted
                        ? AppColors.success
                        : AppColors.border,
                  ),
                ),
            ],
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:  MainAxisAlignment.center,
              children: [
                Text(title,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isCompleted || isCurrent
                          ? AppColors.textPrimary
                          : AppColors.textTertiary,
                    )),
                const SizedBox(height: 2),
                Text(time,
                    style: AppTextStyles.caption.copyWith(
                      color: isError
                          ? AppColors.error
                          : AppColors.textSecondary,
                    )),
              ],
            ),
          ),
        ],
      ),
    );
  }
}