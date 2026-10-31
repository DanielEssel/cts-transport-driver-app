// Active jobs — queries the job collections directly (trips / deliveries /
// gas_orders where driverId == me, status in an active stage). Does NOT depend on
// drivers/{uid}.currentTripId, so it works regardless of which accept path
// ran. Powers both this screen and the home banner.
//
// Gas supplier jobs are added from the server (listMyGasSupplierJobs, see
// supplier_active_jobs.dart): drivers cannot read gas_supplier_orders, so
// they are never queried here, and each order appears once.

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cts_transport_driver_app/features/trips/presentation/trip_flow_screen.dart';
import '../../../jobs/screens/active_delivery_screen.dart';
import '../../../jobs/screens/active_gas_order_screen.dart';
import 'package:cts_transport_driver_app/features/gas_supplier_jobs/data/gas_supplier_job_repository.dart';
import 'package:cts_transport_driver_app/features/gas_supplier_jobs/domain/gas_supplier_job.dart';
import 'package:cts_transport_driver_app/features/gas_supplier_jobs/presentation/supplier_active_jobs.dart';

// ── Model ─────────────────────────────────────────────────────────────────

class ActiveJob {
  final String id;
  final String collection; // 'trips' | 'deliveries' | 'gas_orders' | 'gas_supplier_orders'
  final String status;
  final String from;
  final String to;
  final double? fare;
  final DateTime? createdAt;
  /// For a Gas supplier job: the server's view of it, and the repository to act through.
  final GasSupplierJob? supplierJob;
  final GasSupplierJobRepository? supplierRepository;

  const ActiveJob({
    required this.id,
    required this.collection,
    required this.status,
    required this.from,
    required this.to,
    this.fare,
    this.createdAt,
    this.supplierJob,
    this.supplierRepository,
  });

  /// A supplier job as the server returned it; its status is the server's.
  factory ActiveJob.supplier(GasSupplierJob j, GasSupplierJobRepository repo) => ActiveJob(
        id: j.orderId,
        collection: 'gas_supplier_orders',
        status: j.status ?? '',
        from: j.station.name ?? 'Supplier station',
        to: j.delivery.address ?? '—',
        fare: j.deliveryFee,
        supplierJob: j,
        supplierRepository: repo,
      );

  String get typeLabel => switch (collection) {
        'deliveries' => 'Delivery',
        'gas_orders' => 'Gas Order',
        'gas_supplier_orders' => 'Gas supplier job',
        _            => 'Ride',
      };

  IconData get icon => switch (collection) {
        'deliveries' => Icons.inventory_2_rounded,
        'gas_orders' => Icons.local_fire_department_rounded,
        'gas_supplier_orders' => Icons.storefront_rounded,
        _            => Icons.two_wheeler_rounded,
      };

  Widget trackingScreen() => switch (collection) {
        'deliveries' => ActiveDeliveryScreen(deliveryId: id),
        'gas_orders' => ActiveGasOrderScreen(orderId: id),
        'gas_supplier_orders' => SupplierJobRoute(job: supplierJob!, repository: supplierRepository!),
        _            => TripFlowScreen(tripId: id),
      };
}

// ── Provider ──────────────────────────────────────────────────────────────

// Allowlist of in-progress statuses per collection. A denylist let cancelled
// variants (cancelledByDriver, cancelledByPassenger, noDriversAvailable, …)
// leak through as "active", so only these explicit stages count.
const _activeStatuses = <String, Set<String>>{
  'trips': {'tripAccepted', 'driverArrived', 'tripStarted'},
  'deliveries': {
    'driverAssigned', 'pickupEnroute', 'arrivedAtPickup',
    'packagePicked', 'deliveryEnroute', 'arrivedAtDropoff',
  },
  'gas_orders': {
    'driverAssigned', 'driverEnRoute', 'driverArrived',
    'pickedUp', 'atStation', 'refilling', 'returning',
  },
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
            if (!(_activeStatuses[collection]?.contains(status) ?? false)) {
              return null;
            }
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

/// Ride, delivery and Gas order jobs from Firestore (overridable in tests).
final firestoreActiveJobsProvider = Provider.autoDispose<List<ActiveJob>>((ref) => [
      ...ref.watch(_tripsActive).maybeWhen(data: (j) => j, orElse: () => const <ActiveJob>[]),
      ...ref.watch(_deliveriesActive).maybeWhen(data: (j) => j, orElse: () => const <ActiveJob>[]),
      ...ref.watch(_gasActive).maybeWhen(data: (j) => j, orElse: () => const <ActiveJob>[]),
    ]);

/// All non-terminal jobs assigned to this driver, newest first. Supplier
/// jobs (no creation time from the server) follow the others.
final activeJobsProvider = Provider.autoDispose<List<ActiveJob>>((ref) {
  final repo = ref.watch(gasSupplierJobRepositoryProvider);
  final supplier = ref.watch(supplierActiveJobsProvider).valueOrNull;
  final seen = <String>{};
  final all = <ActiveJob>[
    for (final j in ref.watch(firestoreActiveJobsProvider))
      if (seen.add('${j.collection}/${j.id}')) j,
    for (final j in supplier?.jobs ?? const <GasSupplierJob>[])
      if (seen.add('gas_supplier_orders/${j.orderId}')) ActiveJob.supplier(j, repo),
  ];
  all.sort((a, b) => (b.createdAt ?? DateTime(0)).compareTo(a.createdAt ?? DateTime(0)));
  return all;
});

// ── Screen ────────────────────────────────────────────────────────────────

class ActiveJobsScreen extends ConsumerStatefulWidget {
  const ActiveJobsScreen({super.key});

  @override
  ConsumerState<ActiveJobsScreen> createState() => _ActiveJobsScreenState();
}

class _ActiveJobsScreenState extends ConsumerState<ActiveJobsScreen> {
  /// One job screen at a time: a second tap while it opens does nothing.
  bool _opening = false;

  Future<void> _open(ActiveJob job) async {
    if (_opening) return;
    _opening = true;
    try {
      await Navigator.push(context, MaterialPageRoute(builder: (_) => job.trackingScreen()));
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final jobs = ref.watch(activeJobsProvider);
    final supplier = ref.watch(supplierActiveJobsProvider);
    final notice = _supplierNotice(supplier);

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F8),
      appBar: AppBar(
        title: const Text('Active Jobs',
            style: TextStyle(fontWeight: FontWeight.w800)),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF111827),
        elevation: 0.5,
      ),
      body: jobs.isEmpty && notice == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.task_alt_rounded,
                      size: 56, color: Colors.grey[400]),
                  const SizedBox(height: 12),
                  Text('No active jobs',
                      key: const Key('active-jobs-empty'),
                      style: TextStyle(
                          color: Colors.grey[600],
                          fontWeight: FontWeight.w600)),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (notice != null) ...[notice, const SizedBox(height: 10)],
                for (final job in jobs) ...[
                  GestureDetector(
                    key: Key('active-job-${job.collection}-${job.id}'),
                    onTap: () => _open(job),
                    child: _row(job),
                  ),
                  const SizedBox(height: 10),
                ],
              ],
            ),
    );
  }

  /// Supplier jobs come from a callable, not a live query: say when they are
  /// still being checked or could not be, so a missing job is never silent.
  Widget? _supplierNotice(AsyncValue<SupplierActiveJobs> s) {
    final v = s.valueOrNull;
    if (s.isLoading && v == null) {
      return const Padding(
        key: Key('active-jobs-supplier-checking'),
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text('Checking Gas supplier jobs…', style: TextStyle(fontSize: 12, color: Color(0xFF4B5563))),
      );
    }
    if (v == null || !v.enabled || v.error == null) return null;
    return Container(
      key: const Key('active-jobs-supplier-error'),
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline_rounded, color: Color(0xFFB91C1C), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text("Couldn't check your Gas supplier jobs. ${v.error}",
              style: const TextStyle(fontSize: 12.5, color: Color(0xFF7F1D1D))),
        ),
        TextButton(
          key: const Key('active-jobs-supplier-retry'),
          onPressed: () => ref.invalidate(supplierActiveJobsProvider),
          child: const Text('Retry'),
        ),
      ]),
    );
  }

  Widget _row(ActiveJob job) => Container(
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
                  );
}
