import 'package:equatable/equatable.dart';

sealed class DriverFailure extends Equatable {
  final String message;
  const DriverFailure(this.message);
  
  @override
  List<Object> get props => [message];

  @override
  String toString() => message;
}

class LocationPermissionDenied extends DriverFailure {
  const LocationPermissionDenied() : super('Location permission denied');
}

class LocationServiceDisabled extends DriverFailure {
  const LocationServiceDisabled() : super('Location services are disabled');
}

class LocationTimeout extends DriverFailure {
  const LocationTimeout() : super('Location request timeout');
}

class NetworkFailure extends DriverFailure {
  const NetworkFailure() : super('Network connection failure');
}

class RequestNotFound extends DriverFailure {
  const RequestNotFound() : super('Ride request not found');
}

class RequestAlreadyAccepted extends DriverFailure {
  const RequestAlreadyAccepted() : super('This request has already been accepted');
}

class DriverOffline extends DriverFailure {
  const DriverOffline() : super('Driver must be online to perform this action');
}

class FirebaseFailure extends DriverFailure {
  final Object? error;
  final StackTrace? stackTrace;

  const FirebaseFailure({
    this.error,
    this.stackTrace,
    String? message,
  }) : super(message ?? 'A database error occurred. Please try again.');

  @override
  List<Object> get props => [message, error ?? '', stackTrace ?? ''];
}