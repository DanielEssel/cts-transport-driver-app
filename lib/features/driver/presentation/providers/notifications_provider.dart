import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'driver_home_providers.dart';

final unreadNotificationsCountProvider =
    StreamProvider<int>((ref) {
  final repository = ref.watch(driverRepositoryProvider);

  final user = FirebaseAuth.instance.currentUser;

  if (user == null) {
    return Stream.value(0);
  }

  return repository.watchUnreadNotificationsCount(user.uid);
});