import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart';
import 'driver_home_providers.dart';


part 'driver_profile_provider.g.dart';

@riverpod
class DriverProfileNotifier extends _$DriverProfileNotifier {
  
  @override
  Stream<DriverProfile> build() {
    // 1. Watch the use case provider from driver_home_providers.dart
    final getDriverProfile = ref.watch(getDriverProfileProvider);
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      // Return an empty profile or error if not logged in
      return Stream.value(DriverProfile.empty());
    }

    // 2. Return the stream directly. 
    // Riverpod handles the listening and cancellation automatically.
    return getDriverProfile(user.uid).map((result) {
      return result.fold(
        (failure) => throw failure,
        (profile) => profile,
      );
    });
  }

  // Helper to get data without checking AsyncValue manually in some places
  DriverProfile get profile => state.value ?? DriverProfile.empty();
}