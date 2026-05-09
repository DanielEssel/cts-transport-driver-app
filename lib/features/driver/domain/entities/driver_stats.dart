import 'package:equatable/equatable.dart';


// domain/entities/driver_stats.dart
class DriverStats extends Equatable {
  final double rating;
  final int completedTrips;
  final int cancelledTrips;
  final double acceptanceRate;
  final double cancellationRate;
  final int totalDistanceKm;
  final int totalHoursOnline;
  final double totalEarnings;
  final int fiveStarRatings;
  final int fourStarRatings;
  final int threeStarRatings;
  final int twoStarRatings;
  final int oneStarRatings;

  const DriverStats({
    this.rating = 0.0,
    this.completedTrips = 0,
    this.cancelledTrips = 0,
    this.acceptanceRate = 0.0,
    this.cancellationRate = 0.0,
    this.totalDistanceKm = 0,
    this.totalHoursOnline = 0,
    this.totalEarnings = 0.0,
    this.fiveStarRatings = 0,
    this.fourStarRatings = 0,
    this.threeStarRatings = 0,
    this.twoStarRatings = 0,
    this.oneStarRatings = 0,
  });

  double get completionRate => 
      completedTrips + cancelledTrips > 0
          ? completedTrips / (completedTrips + cancelledTrips)
          : 0.0;

  @override
  List<Object?> get props => [rating, completedTrips, cancelledTrips, acceptanceRate, cancellationRate, totalDistanceKm, totalHoursOnline, totalEarnings, fiveStarRatings, fourStarRatings, threeStarRatings, twoStarRatings, oneStarRatings];
}