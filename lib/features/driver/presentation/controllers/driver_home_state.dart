// presentation/controllers/driver_home_state.dart

import '../../domain/entities/driver_stats.dart';
import '../../domain/entities/earnings_summary.dart';

class DriverHomeState {
  final bool isOnline;
  final int unreadNotifications;
  final DriverStats? stats;
  final EarningsSummary? earnings;

  const DriverHomeState({
    this.isOnline = false,
    this.unreadNotifications = 0,
    this.stats,
    this.earnings,
  });

  DriverHomeState copyWith({
    bool? isOnline,
    int? unreadNotifications,
    DriverStats? stats,
    EarningsSummary? earnings,
  }) {
    return DriverHomeState(
      isOnline: isOnline ?? this.isOnline,
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
      stats: stats ?? this.stats,
      earnings: earnings ?? this.earnings,
    );
  }
}