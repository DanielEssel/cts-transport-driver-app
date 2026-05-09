// domain/usecases/get_driver_profile.dart
import 'package:fpdart/fpdart.dart'; // Change dartz to fpdart
import 'package:cts_transport_driver_app/features/driver/models/driver_types.dart';
import '../failures/driver_failures.dart';
import '../repositories/driver_repository.dart';

class GetDriverProfile {
  final DriverRepository repository;
  
  GetDriverProfile(this.repository);
  
  Stream<Either<DriverFailure, DriverProfile>> call(String driverId) {
    return repository.watchDriverProfile(driverId).map<Either<DriverFailure, DriverProfile>>(
      (profile) => Right(profile) // This is now an fpdart Right
    ).handleError(
      (error) => Left(FirebaseFailure(message: error.toString())) // Pass message as named param
    );
  }
}