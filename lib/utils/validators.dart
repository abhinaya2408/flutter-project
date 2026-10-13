import 'phone_number.dart';

/// Validation — the rules and messages from `college-bakery/js/auth.js` and
/// `js/customize.js`. Messages are reproduced verbatim.
class Validators {
  Validators._();

  // ---------- Messages ----------
  static const String emailRequired = 'Please enter a valid email address.';
  static const String passwordRequired = 'Password is required.';
  static const String incorrectCredentials = 'Incorrect email or password.';
  static const String accountUnavailable =
      'Could not load your account. Please try again.';
  static const String networkUnavailable =
      'You appear to be offline. Check your connection and try again.';
  static const String genericError = 'Something went wrong. Please try again.';
  static const String fullNameRequired = 'Full name is required.';
  static const String studentIdRequired = 'Student ID is required.';
  static const String phoneInvalid = 'Enter a valid 10-digit phone number.';
  static const String collegeEmailRequired =
      'Please use your official college email address.';
  static const String passwordTooShort =
      'Password must be at least 6 characters.';
  static const String passwordsDoNotMatch = 'Passwords do not match.';
  static const String emailAlreadyExists =
      'An account with this email already exists.';
  static const String studentIdAlreadyExists =
      'This Student ID is already registered.';
  static const String imageTypeInvalid = 'Please upload a JPG or PNG image.';
  static const String imageTooLarge =
      'Please upload an image smaller than 2 MB.';
  static const String imageReadFailed =
      'Could not read this image. Please try another file.';
  static const String otpPhoneInvalid =
      'Enter a valid phone number, including the country code.';
  static const String otpCodeInvalid =
      'Enter the 6-digit code sent on WhatsApp.';
  static const String dateRequired = 'Please select a date.';
  static const String dateInPast = 'Please choose a date that is today or later.';
  static const String timeRequired = 'Please select a time.';

  /// `COLLEGE_EMAIL_DOMAIN`
  static const String collegeEmailDomain = '@yourcollege.edu';

  /// `file.type` allow-list in `wireImageUpload()`.
  static const List<String> allowedImageMimeTypes = <String>[
    'image/jpeg',
    'image/jpg',
    'image/png',
  ];

  /// Accepted file extensions (mirrors the `accept="image/jpeg,image/png,image/jpg"`
  /// attribute plus the mime check).
  static const List<String> allowedImageExtensions = <String>[
    'jpg',
    'jpeg',
    'png',
  ];

  /// `2 * 1024 * 1024`
  static const int maxImageBytes = 2 * 1024 * 1024;

  /// `password.length < 6`
  static const int minPasswordLength = 6;

  /// `<input maxlength="50">` on the cake message.
  static const int cakeMessageMaxLength = 50;

  // ---------- Student login ----------
  /// `!email || !email.includes("@")`
  static String? loginEmail(String value) =>
      (value.isEmpty || !value.contains('@')) ? emailRequired : null;

  /// `!password`
  static String? loginPassword(String value) =>
      value.isEmpty ? passwordRequired : null;

  // ---------- Student registration ----------
  static String? fullName(String value) =>
      value.trim().isEmpty ? fullNameRequired : null;

  static String? studentId(String value) =>
      value.trim().isEmpty ? studentIdRequired : null;

  /// `/^\d{10}$/`
  static String? phone(String value) {
    final RegExp pattern = RegExp(r'^\d{10}$');
    return pattern.hasMatch(value.trim()) ? null : phoneInvalid;
  }

  /// `!email.endsWith(COLLEGE_EMAIL_DOMAIN)`
  static String? collegeEmail(String value) =>
      value.trim().toLowerCase().endsWith(collegeEmailDomain)
          ? null
          : collegeEmailRequired;

  static String? password(String value) =>
      value.length < minPasswordLength ? passwordTooShort : null;

  /// `confirmPassword !== password || !confirmPassword`
  static String? confirmPassword(String value, String passwordValue) =>
      (value != passwordValue || value.isEmpty) ? passwordsDoNotMatch : null;

  // ---------- WhatsApp verification ----------
  /// The national number for the WhatsApp screen, normalised to E.164 with the
  /// selected dial code. Mirrors `functions/src/phone.ts`.
  static String? otpPhoneNumber(String value, {String dialCode = '+91'}) =>
      PhoneNumber.toE164(value, dialCode: dialCode) == null
          ? otpPhoneInvalid
          : null;

  /// `/^\d{6}$/` — the same shape the backend enforces before calling Twilio.
  static String? otpCode(String value) =>
      RegExp(r'^\d{6}$').hasMatch(value.trim()) ? null : otpCodeInvalid;

  // ---------- Customize / place order ----------
  static String? requiredDate(String? value) {
    if (value == null || value.isEmpty) return dateRequired;
    return null;
  }

  /// `customizeState.requiredDate < today`
  static String? dateNotInPast(String value, {required String today}) =>
      value.compareTo(today) < 0 ? dateInPast : null;

  static String? requiredTime(String? value) =>
      (value == null || value.isEmpty) ? timeRequired : null;

  /// The `placeOrder()` aggregate error message:
  /// `"Please complete: " + missing.join(", ") + "."`
  static String missingFieldsMessage(List<String> missing) =>
      'Please complete: ${missing.join(', ')}.';
}
