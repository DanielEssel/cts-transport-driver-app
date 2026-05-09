// lib/shared/utils/phone_formatter.dart

import 'package:flutter/services.dart';

/// Formats input as: 024 XXX XXXX
/// Hard caps at 10 digits, inserts spaces automatically.
class GhanaPhoneFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(' ', '');

    // Hard cap — reject input beyond 10 digits
    if (digits.length > 10) return oldValue;

    // Build formatted string: 024 XXX XXXX
    final buffer = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i == 3 || i == 6) buffer.write(' ');
      buffer.write(digits[i]);
    }

    final formatted = buffer.toString();
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}