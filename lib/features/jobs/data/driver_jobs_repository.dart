// lib/features/jobs/data/driver_jobs_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';

enum JobType { ride, delivery, gas }

enum JobOutcome { completed, cancelled }

class JobSummary {
  final String id;
  final JobType type;
  final JobOutcome outcome;

  /// Who/what the job was for — passenger name (ride), receiver name
  /// (delivery), or a product label (gas). Never assumes a named passenger.
  final String counterparty;
  final String counterpartyInitials;

  final String pickupAddress;
  final String dropoffAddress;
  final DateTime dateTime;
  final double distanceKm;
  final int durationMinutes;
  final double fareGhs;
  final double rating; // 0 when unrated
  final String paymentMethod; // 'Cash' | 'Wallet' | 'MoMo' | '—'

  const JobSummary({
    required this.id,
    required this.type,
    required this.outcome,
    required this.counterparty,
    required this.counterpartyInitials,
    required this.pickupAddress,
    required this.dropoffAddress,
    required this.dateTime,
    required this.distanceKm,
    required this.durationMinutes,
    required this.fareGhs,
    required this.rating,
    required this.paymentMethod,
  });
}

class DriverJobsRepository {
  DriverJobsRepository(this._db);
  final FirebaseFirestore _db;

  // Terminal statuses we show in history.
  static const _terminal = ['completed', 'cancelled'];

  /// Fetch up to [perCollectionLimit] recent terminal jobs from each service,
  /// merged and sorted newest-first. Failures in one collection don't sink the
  /// others — each is guarded so a single bad query still returns the rest.
  Future<List<JobSummary>> fetchHistory(
    String driverId, {
    int perCollectionLimit = 50,
  }) async {
    final results = await Future.wait([
      _fetchTrips(driverId, perCollectionLimit),
      _fetchDeliveries(driverId, perCollectionLimit),
      _fetchGasOrders(driverId, perCollectionLimit),
    ]);

    final all = results.expand((e) => e).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    return all;
  }

  // ── Trips (rides) ─────────────────────────────────────────────────────────
  Future<List<JobSummary>> _fetchTrips(String driverId, int limit) async {
    try {
      final snap = await _db
          .collection('trips')
          .where('driverId', isEqualTo: driverId)
          .where('status', whereIn: _terminal)
          .orderBy('completedAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => _fromTrip(d.data(), d.id)).toList();
    } catch (_) {
      return const [];
    }
  }

  JobSummary _fromTrip(Map<String, dynamic> d, String id) {
    final name = (d['passengerName'] as String?)?.trim();
    return JobSummary(
      id: id,
      type: JobType.ride,
      outcome: _outcome(d['status'] as String?),
      counterparty: (name == null || name.isEmpty) ? 'Passenger' : name,
      counterpartyInitials: _initials(name ?? 'Passenger'),
      pickupAddress: d['pickupAddress'] as String? ?? '—',
      dropoffAddress: d['dropoffAddress'] as String? ?? '—',
      dateTime: _date(d),
      distanceKm: _distance(d),
      durationMinutes: _toInt(d['durationMinutes']),
      fareGhs: _fare(d),
      rating: _toDouble(d['passengerRating'] ?? d['rating']),
      paymentMethod: _payment(d['paymentMethod'] as String?),
    );
  }

  // ── Deliveries ────────────────────────────────────────────────────────────
  Future<List<JobSummary>> _fetchDeliveries(String driverId, int limit) async {
    try {
      final snap = await _db
          .collection('deliveries')
          .where('driverId', isEqualTo: driverId)
          .where('status', whereIn: _terminal)
          .orderBy('completedAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => _fromDelivery(d.data(), d.id)).toList();
    } catch (_) {
      return const [];
    }
  }

  JobSummary _fromDelivery(Map<String, dynamic> d, String id) {
    final receiver = (d['receiverName'] as String?)?.trim();
    final label =
        (receiver == null || receiver.isEmpty) ? 'Delivery' : receiver;
    return JobSummary(
      id: id,
      type: JobType.delivery,
      outcome: _outcome(d['status'] as String?),
      counterparty: label,
      counterpartyInitials: _initials(label),
      pickupAddress: d['pickupAddress'] as String? ?? '—',
      dropoffAddress: d['dropoffAddress'] as String? ?? '—',
      dateTime: _date(d),
      distanceKm: _distance(d),
      durationMinutes: _toInt(d['durationMinutes']),
      fareGhs: _fare(d),
      rating: _toDouble(d['passengerRating'] ?? d['rating']),
      paymentMethod: _payment(d['paymentMethod'] as String?),
    );
  }

  // ── Gas orders ────────────────────────────────────────────────────────────
  Future<List<JobSummary>> _fetchGasOrders(String driverId, int limit) async {
    try {
      final snap = await _db
          .collection('gas_orders')
          .where('driverId', isEqualTo: driverId)
          .where('status', whereIn: _terminal)
          .orderBy('completedAt', descending: true)
          .limit(limit)
          .get();
      return snap.docs.map((d) => _fromGas(d.data(), d.id)).toList();
    } catch (_) {
      return const [];
    }
  }

  JobSummary _fromGas(Map<String, dynamic> d, String id) {
    return JobSummary(
      id: id,
      type: JobType.gas,
      outcome: _outcome(d['status'] as String?),
      counterparty: 'Gas delivery',
      counterpartyInitials: 'G',
      pickupAddress: d['pickupAddress'] as String? ?? 'Gas station',
      dropoffAddress: d['dropoffAddress'] as String? ?? '—',
      dateTime: _date(d),
      distanceKm: _distance(d),
      durationMinutes: _toInt(d['durationMinutes']),
      fareGhs: _fare(d),
      rating: _toDouble(d['passengerRating'] ?? d['rating']),
      paymentMethod: _payment(d['paymentMethod'] as String?),
    );
  }

  // ── Shared mappers ────────────────────────────────────────────────────────
  JobOutcome _outcome(String? s) =>
      s == 'cancelled' ? JobOutcome.cancelled : JobOutcome.completed;

  DateTime _date(Map<String, dynamic> d) {
    final ts = (d['completedAt'] ?? d['updatedAt'] ?? d['createdAt'])
        as Timestamp?;
    return ts?.toDate() ?? DateTime.now();
  }

  double _distance(Map<String, dynamic> d) =>
      _toDouble(d['distance'] ?? d['distanceKm']);

  double _fare(Map<String, dynamic> d) =>
      _toDouble(d['actualFare'] ?? d['estimatedFare'] ?? d['fare']);

  String _payment(String? raw) {
    switch ((raw ?? '').toLowerCase()) {
      case 'cash':
        return 'Cash';
      case 'wallet':
        return 'Wallet';
      case 'momo':
      case 'mobile_money':
        return 'MoMo';
      case 'card':
        return 'Card';
      default:
        return '—';
    }
  }

  double _toDouble(dynamic v) =>
      v is num ? v.toDouble() : double.tryParse('$v') ?? 0;

  int _toInt(dynamic v) => v is num ? v.toInt() : int.tryParse('$v') ?? 0;

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return '?';
    if (parts.length == 1) {
      return parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }
}