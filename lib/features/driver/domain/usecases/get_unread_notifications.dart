// domain/usecases/get_unread_notifications.dart

import 'package:dartz/dartz.dart';

import '../failures/driver_failures.dart';
import '../repositories/driver_repository.dart';

class GetUnreadNotifications {
  final DriverRepository repository;

  const GetUnreadNotifications(this.repository);

  Stream<Either<DriverFailure, int>> call(String driverId) async* {
    try {
      await for (final count
          in repository.watchUnreadNotificationsCount(driverId)) {
        yield Right(count);
      }
    } catch (e, stack) {
      yield Left(
        FirebaseFailure(
          error: e,
          stackTrace: stack,
          message: 'Failed to fetch unread notifications',
        ),
      );
    }
  }
}