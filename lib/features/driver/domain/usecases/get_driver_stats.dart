import 'package:fpdart/fpdart.dart'; // Standardizing on fpdart
import '../entities/driver_stats.dart';
import '../failures/driver_failures.dart';
import '../repositories/driver_repository.dart';

class GetDriverStats {
  final DriverRepository repository;

  const GetDriverStats(this.repository);

  // Added curly braces {} to make 'driverId' a named parameter
  Stream<Either<DriverFailure, DriverStats>> call({
    required String driverId,
  }) async* {
    try {
      // Listening to the repository stream
      await for (final stats in repository.watchDriverStats(driverId)) {
        yield Right(stats);
      }
    } catch (e, stack) {
      yield Left(
        FirebaseFailure(
          error: e,
          stackTrace: stack,
          message: 'Failed to load driver stats',
        ),
      );
    }
  }
}