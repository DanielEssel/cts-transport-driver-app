import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../domain/entities/driver_stats.dart';
import 'driver_home_providers.dart';


part 'driver_stats_provider.g.dart';

@riverpod
class DriverStatsNotifier extends _$DriverStatsNotifier {
  
  @override
  Stream<DriverStats> build() {
    // 1. Initialize dependencies
    final getDriverStats = ref.watch(getDriverStatsProvider);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      return Stream.error('User not authenticated');
    }

    // 2. Call use case with NAMED parameters
    // Note: Since the use case returns a Stream of Either, we map it
    return getDriverStats(driverId: user.uid).map((result) {
      return result.fold(
        (failure) => throw failure, // This becomes AsyncError in Riverpod
        (stats) => stats,           // This becomes AsyncData in Riverpod
      );
    });
  }
  
  // Helpers
  DriverStats get stats => state.value ?? const DriverStats();
  bool get hasData => state.hasValue;
  
  void refresh() {
    ref.invalidateSelf();
  }
}