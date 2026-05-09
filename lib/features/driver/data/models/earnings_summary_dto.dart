// data/models/earnings_summary_dto.dart
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/earnings_summary.dart';

class EarningsSummaryDTO {
  final double todayEarnings;
  final double weekEarnings;
  final double monthEarnings;
  final double totalBalance;
  final int todayTrips;
  final int weekTrips;
  final int monthTrips;
  final int totalTrips;
  final double pendingPayout;
  final double availableBalance;
  final double lifetimeEarnings;
  final Map<String, double> earningsByDay;
  final Map<String, double> earningsByWeek;
  final Map<String, double> earningsByMonth;
  final DateTime lastUpdated;

  EarningsSummaryDTO({
    this.todayEarnings = 0.0,
    this.weekEarnings = 0.0,
    this.monthEarnings = 0.0,
    this.totalBalance = 0.0,
    this.todayTrips = 0,
    this.weekTrips = 0,
    this.monthTrips = 0,
    this.totalTrips = 0,
    this.pendingPayout = 0.0,
    this.availableBalance = 0.0,
    this.lifetimeEarnings = 0.0,
    this.earningsByDay = const {},
    this.earningsByWeek = const {},
    this.earningsByMonth = const {},
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  factory EarningsSummaryDTO.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return EarningsSummaryDTO(
      todayEarnings: (data['todayEarnings'] as num?)?.toDouble() ?? 0.0,
      weekEarnings: (data['weekEarnings'] as num?)?.toDouble() ?? 0.0,
      monthEarnings: (data['monthEarnings'] as num?)?.toDouble() ?? 0.0,
      totalBalance: (data['totalBalance'] as num?)?.toDouble() ?? 0.0,
      todayTrips: data['todayTrips'] ?? 0,
      weekTrips: data['weekTrips'] ?? 0,
      monthTrips: data['monthTrips'] ?? 0,
      totalTrips: data['totalTrips'] ?? 0,
      pendingPayout: (data['pendingPayout'] as num?)?.toDouble() ?? 0.0,
      availableBalance: (data['availableBalance'] as num?)?.toDouble() ?? 0.0,
      lifetimeEarnings: (data['lifetimeEarnings'] as num?)?.toDouble() ?? 0.0,
      earningsByDay: Map<String, double>.from(data['earningsByDay'] ?? {}),
      earningsByWeek: Map<String, double>.from(data['earningsByWeek'] ?? {}),
      earningsByMonth: Map<String, double>.from(data['earningsByMonth'] ?? {}),
      lastUpdated: (data['lastUpdated'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  EarningsSummary toDomain() {
    return EarningsSummary(
      todayEarnings: todayEarnings,
      weekEarnings: weekEarnings,
      monthEarnings: monthEarnings,
      totalBalance: totalBalance,
      todayTrips: todayTrips,
      weekTrips: weekTrips,
      monthTrips: monthTrips,
      totalTrips: totalTrips,
      pendingPayout: pendingPayout,
      availableBalance: availableBalance,
      lifetimeEarnings: lifetimeEarnings,
      earningsByDay: earningsByDay,
      earningsByWeek: earningsByWeek,
      earningsByMonth: earningsByMonth,
      lastUpdated: lastUpdated,
    );
  }
}