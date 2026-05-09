// domain/usecases/accept_ride_request.dart

import 'package:dartz/dartz.dart';

import '../failures/driver_failures.dart';
import '../repositories/driver_repository.dart';

class AcceptRideRequest {
  final DriverRepository _repository;

  const AcceptRideRequest(this._repository);

  Future<Either<DriverFailure, Unit>> call({
    required String driverId,
    required String requestId,
  }) async {
    try {
      await _repository.acceptRequest(
        driverId: driverId,
        requestId: requestId,
      );

      return right(unit);
    } on DriverFailure catch (failure) {
      return left(failure);
    } catch (error, stackTrace) {
      return left(
        FirebaseFailure(
          error: error,
          stackTrace: stackTrace,
        ),
      );
    }
  }
}