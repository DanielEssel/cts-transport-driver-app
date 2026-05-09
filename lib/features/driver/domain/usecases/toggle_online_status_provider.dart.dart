import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart'; // Add this
import '../../domain/usecases/toggle_online_status.dart';
import '../../presentation/providers/driver_home_providers.dart'; // Import where driverRepositoryProvider lives

// If using manual Providers:
final toggleOnlineStatusProvider = Provider<ToggleOnlineStatus>((ref) {
  // Add 'Provider' suffix here
  final repository = ref.watch(driverRepositoryProvider); 

  return ToggleOnlineStatus(repository);
});