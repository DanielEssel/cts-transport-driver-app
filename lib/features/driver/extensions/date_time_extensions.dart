// extensions/date_time_extensions.dart
import 'package:intl/intl.dart';

extension DateTimeExtensions on DateTime {
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(this);
    
    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    }
  }
  
  String get formattedTime => DateFormat('HH:mm').format(this);
  String get formattedDate => DateFormat('MMM dd, yyyy').format(this);
  String get formattedDateTime => DateFormat('MMM dd, yyyy HH:mm').format(this);
  
  bool get isToday {
    final now = DateTime.now();
    return year == now.year && month == now.month && day == now.day;
  }
  
  bool get isThisWeek {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));
    return isAfter(startOfWeek) && isBefore(endOfWeek);
  }
}

// extensions/double_extensions.dart
extension DoubleExtensions on double {
  String toCurrency({String symbol = 'GHS '}) {
    return '$symbol${toStringAsFixed(2)}';
  }
  
  String toPercentage() {
    return '${toStringAsFixed(0)}%';
  }
  
  String toDistance() {
    return '${toStringAsFixed(1)} km';
  }
  
  String toDuration() {
    return '~${toInt()} min';
  }
  
  String toRating() {
    return toStringAsFixed(1);
  }
  
  double clampToRange(double min, double max) {
    return this < min ? min : (this > max ? max : this);
  }
  
  bool get isAcceptableRating => this >= 4.0;
  bool get isExcellentRating => this >= 4.8;
}

