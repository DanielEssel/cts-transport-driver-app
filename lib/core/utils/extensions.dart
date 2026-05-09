import 'package:intl/intl.dart';

extension NumberFormatting on double? {
  /// Converts 4.856 to "4.9"
  String toRating() {
    if (this == null) return '0.0';
    return this!.toStringAsFixed(1);
  }

  /// Converts 0.95 to "95%"
  String toPercentage() {
    if (this == null) return '0%';
    final percent = (this! * 100).round();
    return '$percent%';
  }

  /// Formats currency for Ghana Cedi (e.g., 150.5 to "GH₵ 150.50")
  String toGHS() {
    if (this == null) return 'GH₵ 0.00';
    return NumberFormat.currency(
      symbol: 'GH₵ ',
      decimalDigits: 2,
    ).format(this);
  }
}