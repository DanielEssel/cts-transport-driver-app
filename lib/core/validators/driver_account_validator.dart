import 'dart:io';

class DriverAccountValidator {
  DriverAccountValidator._();

  static const int maxPhotoSizeMB = 5;

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your full name';
    }

    final name = value.trim();

    if (name.length < 3) {
      return 'Name must contain at least 3 characters';
    }

    if (name.length > 60) {
      return 'Name is too long';
    }

    if (!RegExp(r"^[A-Za-zÀ-ÿ' -]+$").hasMatch(name)) {
      return 'Name contains invalid characters';
    }

    return null;
  }

  static String normalizeName(String value) {
  return value
      .trim()
      .replaceAll(RegExp(r'\s+'), ' ');
}

  static Future<String?> validatePhoto(File? photo) async {
    if (photo == null) {
      return 'A live profile photo is required';
    }

    final exists = await photo.exists();

    if (!exists) {
      return 'Photo could not be found';
    }

    final size = await photo.length();

    if (size > maxPhotoSizeMB * 1024 * 1024) {
      return 'Photo must be smaller than $maxPhotoSizeMB MB';
    }

    return null;
  }
}