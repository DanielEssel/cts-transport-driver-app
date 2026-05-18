// presentation/controllers/driver_home_state.dart

import '../../domain/entities/driver.dart';
import '../../domain/entities/driver_stats.dart';
import '../../domain/entities/earnings_summary.dart';

class DriverHomeState {
  /// Logged in driver profile
  final Driver driver;

  /// Online / Offline switch
  final bool isOnline;

  /// Unread notifications badge
  final int unreadNotifications;

  /// Dashboard analytics
  final DriverStats? stats;
  final EarningsSummary? earnings;

  const DriverHomeState({
    required this.driver,
    required this.isOnline,
    required this.unreadNotifications,
    this.stats,
    this.earnings,
  });

  /// Initial empty state (used before API loads)
  factory DriverHomeState.initial(Driver driver) {
    return DriverHomeState(
      driver: driver,
      isOnline: false,
      unreadNotifications: 0,
      stats: null,
      earnings: null,
    );
  }

  DriverHomeState copyWith({
    Driver? driver,
    bool? isOnline,
    int? unreadNotifications,
    DriverStats? stats,
    EarningsSummary? earnings,
  }) {
    return DriverHomeState(
      driver: driver ?? this.driver,
      isOnline: isOnline ?? this.isOnline,
      unreadNotifications: unreadNotifications ?? this.unreadNotifications,
      stats: stats ?? this.stats,
      earnings: earnings ?? this.earnings,
    );
  }
}