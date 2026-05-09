// domain/usecases/get_pending_requests.dart

import 'package:dartz/dartz.dart';
import '../failures/driver_failures.dart';
import '../repositories/driver_repository.dart';

class GetPendingRequests {
  final DriverRepository repository;

  const GetPendingRequests(this.repository);

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
      ),
    );
  }
}
}