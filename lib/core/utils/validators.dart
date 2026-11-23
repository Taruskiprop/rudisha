import 'package:polyfind/core/constants/app_constants.dart';

// Input validators for PolyFind
class Validators {
  static String? validateSchoolEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }
    final email = value.trim();
    if (!RegExp(r'^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$')
        .hasMatch(email)) {
      return 'Enter a valid email address';
    }
    if (!email.toLowerCase().endsWith(AppConstants.schoolEmailDomain)) {
      return 'Use your school email (${AppConstants.schoolEmailDomain}).';
    }
    return null;
  }

  static String? validateAdmissionNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Admission number is required';
    }
    if (!RegExp(r'^\d{1,32}$').hasMatch(value.trim())) {
      return 'Enter the admission number provided by your school.';
    }
    return null;
  }

  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  static String? validateConfirmPassword(String? value, String password) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  static String? validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    if (value.trim().length > 50) {
      return 'Name must be less than 50 characters';
    }
    return null;
  }

  static String? validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Title is required';
    }
    if (value.trim().length < AppConstants.minTitleLength) {
      return 'Title must be at least ${AppConstants.minTitleLength} characters';
    }
    if (value.trim().length > AppConstants.maxTitleLength) {
      return 'Title must be less than ${AppConstants.maxTitleLength} characters';
    }
    return null;
  }

  static String? validateDescription(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Description is required';
    }
    if (value.trim().length < AppConstants.minDescriptionLength) {
      return 'Description must be at least ${AppConstants.minDescriptionLength} characters';
    }
    if (value.trim().length > AppConstants.maxDescriptionLength) {
      return 'Description must be less than ${AppConstants.maxDescriptionLength} characters';
    }
    return null;
  }

  static String? validateCategory(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please select a category';
    }
    return null;
  }

  static String? validateLocation(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Location is required';
    }
    if (value.trim().length < 3) {
      return 'Location must be at least 3 characters';
    }
    return null;
  }

  static String? validateVerificationAnswer(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please provide an answer';
    }
    if (value.trim().length < AppConstants.minVerificationAnswerLength) {
      return 'Answer must be at least ${AppConstants.minVerificationAnswerLength} characters';
    }
    return null;
  }

  static String? validateRequired(String? value, String fieldName) {
    if (value == null || value.trim().isEmpty) {
      return '$fieldName is required';
    }
    return null;
  }
}
