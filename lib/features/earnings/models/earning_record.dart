import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Immutable earnings aggregate for a single calendar day.
///
/// Firestore path example:
/// drivers/{driverId}/earnings/2026-05-05
@immutable
class EarningsRecord {
  /// Document ID format: yyyy-MM-dd
  final String dayId;

  /// Total completed trips/jobs for the day
  final int totalTrips;

  /// Gross earnings before deductions
  final double grossEarnings;

  /// Platform commission/service fee
  final double platformFee;

  final double totalEarnings;

  /// Final payout amount after deductions
  final double netEarnings;

  /// Optional audit trail
  final List<String> tripIds;

  /// Last server update timestamp
  final DateTime? updatedAt;

  const EarningsRecord({
    required this.dayId,
    required this.totalTrips,
    required this.grossEarnings,
    required this.totalEarnings,
    required this.platformFee,
    required this.netEarnings,
    this.tripIds = const [],
    this.updatedAt,
    
  });

  // ─────────────────────────────────────────────
  // FACTORIES
  // ─────────────────────────────────────────────

  factory EarningsRecord.empty(String dayId) {
    return EarningsRecord(
      dayId: dayId,
      totalTrips: 0,
      grossEarnings: 0,
      platformFee: 0,
      netEarnings: 0,
      totalEarnings: 0,
    );
  }

  factory EarningsRecord.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();

    if (data == null) {
      return EarningsRecord.empty(doc.id);
    }

    return EarningsRecord(
      dayId: doc.id,
      totalTrips: (data['totalTrips'] ?? 0) as int,
      grossEarnings: _toDouble(data['grossEarnings']),
      platformFee: _toDouble(data['platformFee']),
      netEarnings: _toDouble(data['netEarnings']),
      totalEarnings: _toDouble(data['totalEarnings']),
      tripIds: List<String>.from(data['tripIds'] ?? const []),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // ─────────────────────────────────────────────
  // SERIALIZATION
  // ─────────────────────────────────────────────

  Map<String, dynamic> toFirestore() {
    return {
      'totalTrips': totalTrips,
      'grossEarnings': grossEarnings,
      'platformFee': platformFee,
      'netEarnings': netEarnings,
      'totalEarnings': totalEarnings,
      'tripIds': tripIds,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  // ─────────────────────────────────────────────
  // COMPUTED VALUES
  // ─────────────────────────────────────────────

  DateTime get date {
    final parts = dayId.split('-');

    if (parts.length != 3) {
      throw FormatException('Invalid dayId format: $dayId');
    }

    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  bool get hasTrips => totalTrips > 0;

  double get averagePerTrip {
    if (totalTrips == 0) return 0;
    return netEarnings / totalTrips;
  }

  // ─────────────────────────────────────────────
  // MUTATION
  // ─────────────────────────────────────────────

  EarningsRecord copyWith({
    String? dayId,
    int? totalTrips,
    double? grossEarnings,
    double? platformFee,
    double? netEarnings,
    List<String>? tripIds,
    DateTime? updatedAt,
  }) {
    return EarningsRecord(
      dayId: dayId ?? this.dayId,
      totalTrips: totalTrips ?? this.totalTrips,
      grossEarnings: grossEarnings ?? this.grossEarnings,
      totalEarnings: totalEarnings ?? totalEarnings,
      platformFee: platformFee ?? this.platformFee,
      netEarnings: netEarnings ?? this.netEarnings,
      tripIds: tripIds ?? this.tripIds,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  // ─────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────

  static double _toDouble(dynamic value) {
    if (value == null) return 0;

    if (value is int) {
      return value.toDouble();
    }

    if (value is double) {
      return value;
    }

    return double.tryParse(value.toString()) ?? 0;
  }

  // ─────────────────────────────────────────────
  // OVERRIDES
  // ─────────────────────────────────────────────

  @override
  String toString() {
    return '''
EarningsRecord(
  dayId: $dayId,
  totalTrips: $totalTrips,
  grossEarnings: $grossEarnings,
  platformFee: $platformFee,
  netEarnings: $netEarnings
)
''';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is EarningsRecord &&
            runtimeType == other.runtimeType &&
            dayId == other.dayId;
  }

  @override
  int get hashCode => dayId.hashCode;
}