import '../../services/driver_runtime_service.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cts_transport_driver_app/features/driver/domain/entities/driver_stats.dart';
import 'package:cts_transport_driver_app/features/driver/domain/entities/earnings_summary.dart';
import '../providers/driver_home_providers.dart';
import 'driver_home_state.dart';
import '../../domain/entities/driver.dart';



part 'driver_home_controller.g.dart';

@riverpod
class DriverHomeController extends _$DriverHomeController {
  
  final _runtime = DriverRuntimeService();

  @override
  Future<DriverHomeState> build() async {
    // We use ref.watch so if the repository provider changes, 
    // the controller rebuilds automatically.
    return _loadInitialData();
  }

  Future<DriverHomeState> _loadInitialData() async {
    final repo = ref.read(driverRepositoryProvider);
    final driverId = repo.currentDriverId;

    if (driverId.isEmpty) {
      throw Exception("User must be logged in to view dashboard.");
    }

    // Future.wait ensures all data fetches run in parallel for performance
    final results = await Future.wait([
  repo.getDriver(driverId),            // ⭐ ADD THIS FIRST
  repo.getOnlineStatus(driverId),
  repo.getUnreadNotifications(driverId),
  repo.getDriverStats(driverId),
  repo.getEarnings(driverId),
]);

    return DriverHomeState(
  driver: results[0] as Driver,           // ⭐ NEW
  isOnline: results[1] as bool,
  unreadNotifications: results[2] as int,
  stats: results[3] as DriverStats?,
  earnings: results[4] as EarningsSummary?,
);
  }

  // ─────────────────────────────
  // ACTIONS
  // ─────────────────────────────

  Future<void> toggleOnlineStatus() async {
  final repo = ref.read(driverRepositoryProvider);
  final currentState = state.value;
  if (currentState == null) return;

  state = const AsyncLoading();

  state = await AsyncValue.guard(() async {
    final nextStatus = !currentState.isOnline;
    final driverId = repo.currentDriverId;

    if (nextStatus) {
      // 🟢 DRIVER GOING ONLINE
      await _runtime.goOnline();     // start GPS + save FCM token
    } else {
      // 🔴 DRIVER GOING OFFLINE
      await _runtime.goOffline();    // stop GPS tracking
    }

    // Keep your repository logic intact
    await repo.setOnlineStatus(
      driverId: driverId,
      isOnline: nextStatus,
    );

    return currentState.copyWith(isOnline: nextStatus);
  });
}

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _loadInitialData());
  }

  Future<void> markNotificationsRead() async {
    final repo = ref.read(driverRepositoryProvider);
    final currentState = state.value;
    if (currentState == null) return;

    state = await AsyncValue.guard(() async {
      await repo.markNotificationsRead(repo.currentDriverId);
      return currentState.copyWith(unreadNotifications: 0);
    });
  }
}