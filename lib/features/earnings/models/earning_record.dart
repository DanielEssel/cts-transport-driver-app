// features/driver/models/earnings_record.dart

class EarningsRecord {
  final DateTime date;
  final double netEarnings;
  final double totalEarnings;
  final double platformFee;
  final int totalTrips;

  EarningsRecord({
    required this.date,
    required this.netEarnings,
    required this.totalEarnings,
    required this.platformFee,
    required this.totalTrips,
  });

  factory EarningsRecord.fromJson(Map<String, dynamic> json) {
    return EarningsRecord(
      date: DateTime.parse(json['date']),
      netEarnings: json['netEarnings'].toDouble(),
      totalEarnings: json['totalEarnings'].toDouble(),
      platformFee: json['platformFee'].toDouble(),
      totalTrips: json['totalTrips'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'netEarnings': netEarnings,
      'totalEarnings': totalEarnings,
      'platformFee': platformFee,
      'totalTrips': totalTrips,
    };
  }
}