import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

// Domain Imports
import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart';
import '../../domain/entities/ride_request.dart';
import '../../domain/usecases/toggle_online_status.dart';
import '../../domain/usecases/accept_ride_request.dart';
import '../../domain/usecases/get_driver_profile.dart';
import '../../domain/usecases/get_earnings_summary.dart';
import '../../domain/usecases/get_driver_stats.dart';
import '../../domain/usecases/get_pending_requests.dart';
import '../../domain/usecases/decline_ride_request.dart';
import '../../domain/repositories/driver_repository.dart';

// Data Imports
import '../../data/datasources/driver_remote_datasource.dart';
import '../../data/repositories/driver_repository_impl.dart'; // CRITICAL IMPORT
import '../../../driver_auth/providers/auth_provider.dart' show driverIdProvider;

part 'driver_home_providers.g.dart';

// --- Repository Providers ---

@Riverpod(keepAlive: true)
DriverRepository driverRepository(DriverRepositoryRef ref) {
  return DriverRepositoryImpl(
    remoteDataSource: DriverRemoteDataSource(
      firestore: FirebaseFirestore.instance,
    ),
    firebaseAuth: FirebaseAuth.instance,
  );
}

// --- Use Case Providers ---

@Riverpod(keepAlive: true)
GetDriverProfile getDriverProfile(GetDriverProfileRef ref) =>
    GetDriverProfile(ref.watch(driverRepositoryProvider));

@Riverpod(keepAlive: true)
GetDriverStats getDriverStats(GetDriverStatsRef ref) =>
    GetDriverStats(ref.watch(driverRepositoryProvider));

@Riverpod(keepAlive: true)
GetEarningsSummary getEarningsSummary(GetEarningsSummaryRef ref) =>
    GetEarningsSummary(ref.watch(driverRepositoryProvider));

@Riverpod(keepAlive: true)
ToggleOnlineStatus toggleOnlineStatus(ToggleOnlineStatusRef ref) =>
    ToggleOnlineStatus(ref.watch(driverRepositoryProvider));

@Riverpod(keepAlive: true)
AcceptRideRequest acceptRideRequest(AcceptRideRequestRef ref) =>
    AcceptRideRequest(ref.watch(driverRepositoryProvider));

// FIXED: Parameter name changed from 'DeclineRideRequest' to 'ref'
@Riverpod(keepAlive: true)
DeclineRideRequest declineRideRequest(DeclineRideRequestRef ref) =>
    DeclineRideRequest(ref.watch(driverRepositoryProvider));

// FIXED: Return type corrected to match the UseCase class
@Riverpod(keepAlive: true)
GetPendingRequests getPendingRequests(GetPendingRequestsRef ref) =>
    GetPendingRequests(ref.watch(driverRepositoryProvider));

@Riverpod(keepAlive: true)
GetEarningsSummary getEarnings(GetEarningsSummaryRef ref) =>
    GetEarningsSummary(ref.watch(driverRepositoryProvider));

// --- Stream Providers ---

@riverpod
Stream<DriverProfile> driverProfile(DriverProfileRef ref, String uid) {
  return ref.watch(driverRepositoryProvider).watchDriverProfile(uid);
}

@riverpod
Stream<List<RideRequest>> pendingRequests(
  PendingRequestsRef ref, 
  String uid, 
  String serviceType,
) {
  return ref.watch(driverRepositoryProvider).watchPendingRequests(
    driverId: uid,
    serviceType: serviceType,
  );
}

// --- Notifiers ---

@riverpod
class OnlineStatus extends _$OnlineStatus {
  @override
  FutureOr<bool> build() async => false;
  
  Future<void> toggle() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final useCase = ref.read(toggleOnlineStatusProvider);
    final currentStatus = state.value ?? false;
    final nextStatus = !currentStatus;

    state = const AsyncLoading();

    state = await AsyncValue.guard(() async {
      await useCase(
        driverId: user.uid,
        isOnline: nextStatus,
      );
      return nextStatus;
    });
  }
}

/// Live unread count of one driver's notifications (drivers/{uid}/notifications,
/// owner-only in the rules), by the `isRead` flag the backend writes.
typedef UnreadNotificationCount = Stream<int> Function(String driverId);

final unreadNotificationCountSourceProvider =
    Provider<UnreadNotificationCount>((ref) {
  final remote = DriverRemoteDataSource(firestore: FirebaseFirestore.instance);
  return (driverId) =>
      remote.watchUnreadNotificationsCount(driverId).map((s) => s.size);
});

/// The bell's count for the signed-in driver. It follows the auth state, so a
/// bell built before sign-in completes picks up the driver when they arrive
/// (and drops to 0 on sign-out); one listener per driver, disposed with the
/// bell.
final driverUnreadCountProvider = StreamProvider.autoDispose<int>((ref) {
  final driverId = ref.watch(driverIdProvider);
  if (driverId == null || driverId.isEmpty) return Stream.value(0);
  return ref.watch(unreadNotificationCountSourceProvider)(driverId);
});