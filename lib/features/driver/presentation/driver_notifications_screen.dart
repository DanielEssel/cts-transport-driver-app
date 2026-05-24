// lib/features/driver/presentation/driver_notifications_screen.dart

import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

import '../../../app/app_routes.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_text_styles.dart';

// ─────────────────────────────────────────────────────────────────────────────
// MODEL
// ─────────────────────────────────────────────────────────────────────────────

enum NotificationType {
  rideRequest,
  delivery,
  gasOrder,
  payment,
  withdrawal,
  accountApproved,
  documentsRejected,
  documentExpiry,
  system,
  promo,
}

class DriverNotification {
  final String           id;
  final String           title;
  final String           body;
  final NotificationType type;
  final bool             isRead;
  final DateTime         createdAt;
  final String?          route;
  final Map<String, dynamic>? metadata;

  const DriverNotification({
    required this.id,
    required this.title,
    required this.body,
    required this.type,
    required this.isRead,
    required this.createdAt,
    this.route,
    this.metadata,
  });

  factory DriverNotification.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return DriverNotification(
      id:       doc.id,
      title:    d['title']  as String? ?? '',
      body:     d['body']   as String? ?? '',
      type:     NotificationType.values.firstWhere(
        (e) => e.name == (d['type'] ?? 'system'),
        orElse: () => NotificationType.system,
      ),
      isRead:   d['isRead'] as bool? ?? d['read'] as bool? ?? false,
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      route:    d['route']  as String?,
      metadata: d['metadata'] as Map<String, dynamic>?,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SCREEN
// ─────────────────────────────────────────────────────────────────────────────

class DriverNotificationsScreen extends StatelessWidget {
  const DriverNotificationsScreen({super.key});

  static final _uid = FirebaseAuth.instance.currentUser?.uid ?? '';

  Stream<QuerySnapshot> get _stream => FirebaseFirestore.instance
      .collection('drivers')
      .doc(_uid)
      .collection('notifications')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots();

  Future<void> _markAllRead() async {
    final snap = await FirebaseFirestore.instance
        .collection('drivers')
        .doc(_uid)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .get();

    final batch = FirebaseFirestore.instance.batch();
    for (final doc in snap.docs) {
      batch.update(doc.reference, {'isRead': true});
    }
    await batch.commit();
  }

  Future<void> _markRead(String id) async {
    await FirebaseFirestore.instance
        .collection('drivers')
        .doc(_uid)
        .collection('notifications')
        .doc(id)
        .update({'isRead': true});
  }

  Future<void> _delete(String id) async {
    await FirebaseFirestore.instance
        .collection('drivers')
        .doc(_uid)
        .collection('notifications')
        .doc(id)
        .delete();
  }

  void _navigate(BuildContext context, DriverNotification n) {
    _markRead(n.id);
    if (n.route == null) return;

    switch (n.type) {
      case NotificationType.accountApproved:
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.driverPhone, (_) => false);
        break;
      case NotificationType.documentsRejected:
        Navigator.pushNamed(context, AppRoutes.driverDocuments);
        break;
      case NotificationType.documentExpiry:
        Navigator.pushNamed(context, AppRoutes.driverDocuments);
        break;
      case NotificationType.payment:
      case NotificationType.withdrawal:
        Navigator.pushNamed(context, AppRoutes.driverWallet);
        break;
      case NotificationType.rideRequest:
      case NotificationType.delivery:
      case NotificationType.gasOrder:
        Navigator.pushNamedAndRemoveUntil(
            context, AppRoutes.driverShell, (_) => false);
        break;
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation:       0,
        title: const Text('Notifications',
            style: AppTextStyles.heading3),
        actions: [
          TextButton(
            onPressed: _markAllRead,
            child: Text('Mark all read',
                style: AppTextStyles.caption
                    .copyWith(color: AppColors.primary)),
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _stream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Text('Something went wrong',
                  style: AppTextStyles.bodySmall
                      .copyWith(color: AppColors.textSecondary)),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) return const _EmptyState();

          final notifications = docs
              .map((d) => DriverNotification.fromFirestore(d))
              .toList();

          // Group by date
          final grouped = <String, List<DriverNotification>>{};
          for (final n in notifications) {
            grouped.putIfAbsent(_dateKey(n.createdAt), () => []).add(n);
          }

          return ListView(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 8),
            children: grouped.entries.map((entry) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(entry.key,
                        style: AppTextStyles.caption.copyWith(
                          fontWeight: FontWeight.w700,
                          color:      AppColors.textSecondary,
                        )),
                  ),
                  ...entry.value.map((n) => _NotifTile(
                        notif:     n,
                        onTap:     () => _navigate(context, n),
                        onDismiss: () => _delete(n.id),
                      )),
                ],
              );
            }).toList(),
          );
        },
      ),
    );
  }

  String _dateKey(DateTime dt) {
    final now = DateTime.now();
    if (_sameDay(dt, now)) return 'Today';
    if (_sameDay(dt, now.subtract(const Duration(days: 1)))) {
      return 'Yesterday';
    }
    return DateFormat('MMMM d, yyyy').format(dt);
  }

  bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;
}

// ─────────────────────────────────────────────────────────────────────────────
// NOTIFICATION TILE
// ─────────────────────────────────────────────────────────────────────────────

class _NotifTile extends StatelessWidget {
  final DriverNotification notif;
  final VoidCallback       onTap;
  final VoidCallback       onDismiss;

  const _NotifTile({
    required this.notif,
    required this.onTap,
    required this.onDismiss,
  });

  IconData get _icon => switch (notif.type) {
    NotificationType.rideRequest      => Icons.directions_car_rounded,
    NotificationType.delivery         => Icons.local_shipping_rounded,
    NotificationType.gasOrder         => Icons.local_fire_department_rounded,
    NotificationType.payment          => Icons.account_balance_wallet_rounded,
    NotificationType.withdrawal       => Icons.arrow_upward_rounded,
    NotificationType.accountApproved  => Icons.verified_rounded,
    NotificationType.documentsRejected=> Icons.warning_rounded,
    NotificationType.documentExpiry   => Icons.event_rounded,
    NotificationType.promo            => Icons.local_offer_rounded,
    NotificationType.system           => Icons.info_rounded,
  };

  Color get _color => switch (notif.type) {
    NotificationType.rideRequest      => AppColors.primary,
    NotificationType.delivery         => AppColors.warning,
    NotificationType.gasOrder         => Colors.deepOrange,
    NotificationType.payment          => AppColors.success,
    NotificationType.withdrawal       => AppColors.info,
    NotificationType.accountApproved  => AppColors.success,
    NotificationType.documentsRejected=> AppColors.error,
    NotificationType.documentExpiry   => AppColors.warning,
    NotificationType.promo            => const Color(0xFFFFB74D),
    NotificationType.system           => const Color(0xFF607D8B),
  };

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key:       Key(notif.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss(),
      background: Container(
        alignment: Alignment.centerRight,
        padding:   const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(
          color:        AppColors.errorLight,
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Icon(Icons.delete_outline_rounded,
            color: AppColors.error),
      ),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin:   const EdgeInsets.only(bottom: 10),
          padding:  const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: notif.isRead
                ? AppColors.background
                : _color.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: notif.isRead
                  ? AppColors.border
                  : _color.withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Icon
              Container(
                width: 42, height: 42,
                decoration: BoxDecoration(
                  color:        _color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(_icon, color: _color, size: 20),
              ),
              const SizedBox(width: 12),

              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(notif.title,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontWeight: notif.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                color: AppColors.textPrimary,
                              )),
                        ),
                        Text(
                          _timeLabel(notif.createdAt),
                          style: AppTextStyles.caption.copyWith(
                              color: AppColors.textTertiary),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(notif.body,
                        style: AppTextStyles.caption.copyWith(
                            color: AppColors.textSecondary),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis),

                    // Action hint for actionable types
                    if (!notif.isRead &&
                        (notif.type ==
                                NotificationType.documentsRejected ||
                            notif.type ==
                                NotificationType.documentExpiry)) ...[
                      const SizedBox(height: 6),
                      Text('Tap to re-upload →',
                          style: AppTextStyles.caption.copyWith(
                            color:      _color,
                            fontWeight: FontWeight.w600,
                          )),
                    ],

                    if (!notif.isRead &&
                        notif.type ==
                            NotificationType.accountApproved) ...[
                      const SizedBox(height: 6),
                      Text('Tap to start driving →',
                          style: AppTextStyles.caption.copyWith(
                            color:      _color,
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ],
                ),
              ),

              // Unread dot
              if (!notif.isRead) ...[
                const SizedBox(width: 8),
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                      color: _color, shape: BoxShape.circle),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _timeLabel(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1)  return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24)   return '${diff.inHours}h ago';
    return DateFormat('MMM d').format(dt);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// EMPTY STATE
// ─────────────────────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(
                color:        AppColors.primaryDim,
                borderRadius: BorderRadius.circular(20),
              ),
              child: const Icon(Icons.notifications_off_outlined,
                  size: 36, color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text('No notifications yet',
                style: AppTextStyles.heading4),
            const SizedBox(height: 8),
            Text("You're all caught up!",
                style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary)),
          ],
        ),
      );
}