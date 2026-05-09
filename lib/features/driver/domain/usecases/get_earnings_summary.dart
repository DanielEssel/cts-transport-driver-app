import 'package:fpdart/fpdart.dart';
import '../entities/earnings_summary.dart';
import '../repositories/driver_repository.dart';
import '../failures/driver_failures.dart';

class GetEarningsSummary {
  final DriverRepository repository;

  GetEarningsSummary(this.repository);

  Stream<Either<FirebaseFailure, EarningsSummary>> call(String driverId) {
    // 1. We call the repository's watch method
    return repository.watchEarningsSummary(driverId).map<Either<FirebaseFailure, EarningsSummary>>(
      // 2. If data arrives, wrap it in a 'Right'
      (earnings) => Right(earnings),
    ).handleError((error) {
      // 3. If a Firebase error occurs, wrap it in a 'Left'
      return Left(FirebaseFailure(
        message: error.toString(),
        error: error,
      ));
    });
  }
}