import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';


class EarningsSummary extends Equatable {
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

   EarningsSummary({
    this.todayEarnings = 0,
    this.weekEarnings = 0,
    this.monthEarnings = 0,
    this.totalBalance = 0,
    this.todayTrips = 0,
    this.weekTrips = 0,
    this.monthTrips = 0,
    this.totalTrips = 0,
    this.pendingPayout = 0,
    this.availableBalance = 0,
    this.lifetimeEarnings = 0,
    this.earningsByDay = const {},
    this.earningsByWeek = const {},
    this.earningsByMonth = const {},
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  // ─────────────────────────────
  // Computed
  // ─────────────────────────────

  double get averageEarningPerTrip {
    if (totalTrips <= 0) return 0;
    return lifetimeEarnings / totalTrips;
  }

  bool get hasEarningsToday => todayEarnings > 0;

  bool get hasEarningsThisWeek => weekEarnings > 0;

  bool get isBalanceLow => availableBalance < 20;

  bool get canWithdraw => availableBalance >= 10;

  // ─────────────────────────────
  // Serialization
  // ─────────────────────────────

  factory EarningsSummary.fromMap(Map<String, dynamic> map) {
    return EarningsSummary(
      todayEarnings: (map['todayEarnings'] as num?)?.toDouble() ?? 0,
      weekEarnings: (map['weekEarnings'] as num?)?.toDouble() ?? 0,
      monthEarnings: (map['monthEarnings'] as num?)?.toDouble() ?? 0,
      totalBalance: (map['totalBalance'] as num?)?.toDouble() ?? 0,

      todayTrips: (map['todayTrips'] as num?)?.toInt() ?? 0,
      weekTrips: (map['weekTrips'] as num?)?.toInt() ?? 0,
      monthTrips: (map['monthTrips'] as num?)?.toInt() ?? 0,
      totalTrips: (map['totalTrips'] as num?)?.toInt() ?? 0,

      pendingPayout: (map['pendingPayout'] as num?)?.toDouble() ?? 0,
      availableBalance: (map['availableBalance'] as num?)?.toDouble() ?? 0,
      lifetimeEarnings: (map['lifetimeEarnings'] as num?)?.toDouble() ?? 0,

      earningsByDay: _parseDoubleMap(map['earningsByDay']),
      earningsByWeek: _parseDoubleMap(map['earningsByWeek']),
      earningsByMonth: _parseDoubleMap(map['earningsByMonth']),

      lastUpdated:
          (map['lastUpdated'] as Timestamp?)?.toDate() ??
              DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'todayEarnings': todayEarnings,
      'weekEarnings': weekEarnings,
      'monthEarnings': monthEarnings,
      'totalBalance': totalBalance,

      'todayTrips': todayTrips,
      'weekTrips': weekTrips,
      'monthTrips': monthTrips,
      'totalTrips': totalTrips,

      'pendingPayout': pendingPayout,
      'availableBalance': availableBalance,
      'lifetimeEarnings': lifetimeEarnings,

      'earningsByDay': earningsByDay,
      'earningsByWeek': earningsByWeek,
      'earningsByMonth': earningsByMonth,

      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  static Map<String, double> _parseDoubleMap(dynamic value) {
    if (value is! Map) return {};

    return value.map(
      (key, val) => MapEntry(
        key.toString(),
        (val as num).toDouble(),
      ),
    );
  }

  // ─────────────────────────────
  // CopyWith
  // ─────────────────────────────

  EarningsSummary copyWith({
    double? todayEarnings,
    double? weekEarnings,
    double? monthEarnings,
    double? totalBalance,
    int? todayTrips,
    int? weekTrips,
    int? monthTrips,
    int? totalTrips,
    double? pendingPayout,
    double? availableBalance,
    double? lifetimeEarnings,
    Map<String, double>? earningsByDay,
    Map<String, double>? earningsByWeek,
    Map<String, double>? earningsByMonth,
    DateTime? lastUpdated,
  }) {
    return EarningsSummary(
      todayEarnings: todayEarnings ?? this.todayEarnings,
      weekEarnings: weekEarnings ?? this.weekEarnings,
      monthEarnings: monthEarnings ?? this.monthEarnings,
      totalBalance: totalBalance ?? this.totalBalance,

      todayTrips: todayTrips ?? this.todayTrips,
      weekTrips: weekTrips ?? this.weekTrips,
      monthTrips: monthTrips ?? this.monthTrips,
      totalTrips: totalTrips ?? this.totalTrips,

      pendingPayout: pendingPayout ?? this.pendingPayout,
      availableBalance: availableBalance ?? this.availableBalance,
      lifetimeEarnings: lifetimeEarnings ?? this.lifetimeEarnings,

      earningsByDay: earningsByDay ?? this.earningsByDay,
      earningsByWeek: earningsByWeek ?? this.earningsByWeek,
      earningsByMonth: earningsByMonth ?? this.earningsByMonth,

      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }

  @override
  List<Object?> get props => [
        todayEarnings,
        weekEarnings,
        monthEarnings,
        totalBalance,
        todayTrips,
        weekTrips,
        monthTrips,
        totalTrips,
        pendingPayout,
        availableBalance,
        lifetimeEarnings,
        earningsByDay,
        earningsByWeek,
        earningsByMonth,
        lastUpdated,
      ];
}