// Active jobs — queries the job collections directly (trips / deliveries /
// gas_orders where driverId == me, status non-terminal). Does NOT depend on
// drivers/{uid}.currentTripId, so it works regardless of which accept path
// ran. Powers both this screen and the home banner.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cts_transport_driver_app/features/trips/presentation/trip_flow_screen.dart';
import '../../../jobs/screens/active_delivery_screen.dart';
import '../../../jobs/screens/active_gas_order_screen.dart';

// ── Model ─────────────────────────────────────────────────────────────────

class ActiveJob {
  final String id;
  final String collection; // 'trips' | 'deliveries' | 'gas_orders'
  final String status;
  final String from;
  final String to;
  final double? fare;
  final DateTime? createdAt;

  const ActiveJob({
    required this.id,
    required this.collection,
    required this.status,
    required this.from,
    required this.to,
    this.fare,
    this.createdAt,
  });

  String get typeLabel => switch (collection) {
        'deliveries' => 'Delivery',
        'gas_orders' => 'Gas Order',
        _            => 'Ride',
      };

  IconData get icon => switch (collection) {
        'deliveries' => Icons.inventory_2_rounded,
        'gas_orders' => Icons.local_fire_department_rounded,
        _            => Icons.two_wheeler_rounded,
      };

  Widget trackingScreen() => switch (collection) {
        'deliveries' => ActiveDeliveryScreen(deliveryId: id),
        'gas_orders' => ActiveGasOrderScreen(orderId: id),
        _            => TripFlowScreen(tripId: id),
      };
}

// ── Provider ──────────────────────────────────────────────────────────────

const _terminalStatuses = {
  'completed', 'delivered', 'cancelled', 'declined', 'expired', 'failed',
};

Stream<List<ActiveJob>> _watchCollection(String collection, String uid) {
  return FirebaseFirestore.instance
      .collection(collection)
      .where('driverId', isEqualTo: uid)
      .limit(10)
      .snapshots()
      .map((snap) => snap.docs
          .map((doc) {
            final d = doc.data();
            final status = (d['status'] as String? ?? '').trim();
            if (_terminalStatuses.contains(status)) return null;
            return ActiveJob(
              id: doc.id,
              collection: collection,
              status: status,
              from: d['pickupAddress'] as String? ?? '—',
              to: d['dropoffAddress'] as String? ??
                  d['deliveryAddress'] as String? ?? '—',
              fare: (d['estimatedFare'] ?? d['actualFare'] ?? d['totalPrice']
                      as num?)
                  ?.toDouble(),
              createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
            );
          })
          .whereType<ActiveJob>()
          .toList());
}

final _tripsActive = StreamProvider.autoDispose<List<ActiveJob>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);
  return _watchCollection('trips', uid);
});
final _deliveriesActive = StreamProvider.autoDispose<List<ActiveJob>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);
  return _watchCollection('deliveries', uid);
});
final _gasActive = StreamProvider.autoDispose<List<ActiveJob>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(const []);
  return _watchCollection('gas_orders', uid);
});

/// All non-terminal jobs assigned to this driver, newest first.
final activeJobsProvider = Provider.autoDispose<List<ActiveJob>>((ref) {
  final all = <ActiveJob>[
    ...ref.watch(_tripsActive).maybeWhen(data: (j) => j, orElse: () => const <ActiveJob>[]),
    ...ref.watch(_deliveriesActive).maybeWhen(data: (j) => j, orElse: () => const <ActiveJob>[]),
    ...ref.watch(_gasActive).maybeWhen(data: (j) => j, orElse: () => const <ActiveJob>[]),
  ];
  all.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  return all;
});

// ── Screen ────────────────────────────────────────────────────────────────

class ActiveJobsScreen extends ConsumerWidget {
  const ActiveJobsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobs = ref.watch(activeJobsProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        title: const Text('Active Jobs',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.5,
      ),
      body: jobs.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.task_alt_rounded,
                      size: 56, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('No active jobs',
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: jobs.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final job = jobs[i];
                return GestureDetector(
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => job.trackingScreen()),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 42, height: 42,
                          decoration: BoxDecoration(
                            color: const Color(0xFF16A34A)
                                .withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(job.icon,
                              color: const Color(0xFF16A34A), size: 22),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(children: [
                                Text(job.typeLabel,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 14)),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDCFCE7),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Text(job.status,
                                      style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: Color(0xFF15803D))),
                                ),
                              ]),
                              const SizedBox(height: 4),
                              Text('${job.from} → ${job.to}',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey[600])),
                            ],
                          ),
                        ),
                        const Icon(Icons.arrow_forward_ios_rounded,
                            size: 14, color: Color(0xFF9CA3AF)),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}