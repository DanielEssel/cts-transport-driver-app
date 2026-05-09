// domain/usecases/decline_ride_request.dart

import 'package:fpdart/fpdart.dart'; // Standardizing on fpdart
import '../failures/driver_failures.dart';
import '../repositories/driver_repository.dart';

class DeclineRideRequest {
  final DriverRepository repository;

  const DeclineRideRequest(this.repository);

  /// We return 'Unit' instead of 'void' in functional programming 
  /// to represent a successful operation with no return value.
  Future<Either<DriverFailure, Unit>> call({
    required String driverId,
    required String requestId,
  }) async {
    try {
      await repository.declineRequest(
        driverId: driverId,
        requestId: requestId,
      );

      return const Right(unit); // 'unit' is the fpdart equivalent of 'null/void'
    } on DriverFailure catch (e) {
      return Left(e);
    } catch (e) {
      return Left(
        FirebaseFailure(
          message: 'Failed to decline ride request: ${e.toString()}',
        ),
      );
    }
  }
}