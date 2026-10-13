/// Result types for the WhatsApp OTP flow.
///
/// Deliberately free of any Firebase import so the parsing rules — including
/// "a malformed payload must never read as success" — can be unit tested
/// without initialising Firebase.
library;

/// Which account operation a verification is being used for.
enum OtpIntent {
  /// The caller is signed out: a correct code yields a Firebase custom token.
  signIn('sign_in'),

  /// The caller is already signed in: a correct code attaches the number to
  /// their own account.
  link('link');

  const OtpIntent(this.wire);

  /// The value the backend expects in the `intent` field.
  final String wire;
}

/// The role of the account a verification resolved to. Mirrors the two
/// Firestore profile collections; the backend never lets the client pick it.
enum WhatsAppAccountRole {
  student('student'),
  bakeryMember('bakery_member');

  const WhatsAppAccountRole(this.wire);

  final String wire;

  static WhatsAppAccountRole? fromWire(Object? value) {
    for (final WhatsAppAccountRole role in WhatsAppAccountRole.values) {
      if (role.wire == value) return role;
    }
    return null;
  }
}

/// What a successful verification did.
enum WhatsAppVerificationStatus {
  signedIn('signed_in'),
  linked('linked');

  const WhatsAppVerificationStatus(this.wire);

  final String wire;

  static WhatsAppVerificationStatus? fromWire(Object? value) {
    for (final WhatsAppVerificationStatus status
        in WhatsAppVerificationStatus.values) {
      if (status.wire == value) return status;
    }
    return null;
  }
}

/// The response to a code request. Never contains the code itself.
class OtpChallenge {
  const OtpChallenge({
    required this.phoneMasked,
    required this.expiresInSeconds,
    required this.resendAfterSeconds,
  });

  /// The number as the provider saw it, masked — never the full number.
  final String phoneMasked;

  /// How long the code stays valid.
  final int expiresInSeconds;

  /// How long the user must wait before requesting another code.
  final int resendAfterSeconds;

  /// Throws [FormatException] when the payload is not a valid `sent` result,
  /// so a broken response can never be mistaken for a delivered code.
  factory OtpChallenge.fromMap(Map<String, dynamic> map) {
    if (map['status'] != 'sent') {
      throw const FormatException('Unexpected OTP request status.');
    }
    final Object? masked = map['phoneMasked'];
    if (masked is! String || masked.isEmpty) {
      throw const FormatException('Missing masked phone number.');
    }
    return OtpChallenge(
      phoneMasked: masked,
      expiresInSeconds: _positiveInt(map['expiresInSeconds'], fallback: 600),
      resendAfterSeconds: _positiveInt(map['resendAfterSeconds'], fallback: 60),
    );
  }
}

/// The response to a successful code check.
class WhatsAppVerification {
  const WhatsAppVerification({
    required this.status,
    required this.uid,
    required this.role,
    required this.phoneMasked,
    this.customToken,
  });

  final WhatsAppVerificationStatus status;

  /// The Firebase uid the verification resolved to.
  final String uid;

  /// Informational: the client still loads the profile document before routing,
  /// so this value is never trusted on its own.
  final WhatsAppAccountRole role;

  final String phoneMasked;

  /// Present for [WhatsAppVerificationStatus.signedIn] only.
  final String? customToken;

  /// Throws [FormatException] on anything that is not a complete success
  /// payload. In particular a `signed_in` result without a usable custom token
  /// is rejected rather than treated as signed in.
  factory WhatsAppVerification.fromMap(Map<String, dynamic> map) {
    final WhatsAppVerificationStatus? status =
        WhatsAppVerificationStatus.fromWire(map['status']);
    if (status == null) {
      throw const FormatException('Unexpected verification status.');
    }

    final Object? uid = map['uid'];
    if (uid is! String || uid.isEmpty) {
      throw const FormatException('Missing uid.');
    }

    final WhatsAppAccountRole? role =
        WhatsAppAccountRole.fromWire(map['role']);
    if (role == null) {
      throw const FormatException('Missing or unknown role.');
    }

    final Object? masked = map['phoneMasked'];
    final Object? token = map['customToken'];

    if (status == WhatsAppVerificationStatus.signedIn) {
      if (token is! String || token.isEmpty) {
        throw const FormatException('Missing custom token.');
      }
      return WhatsAppVerification(
        status: status,
        uid: uid,
        role: role,
        phoneMasked: masked is String ? masked : '',
        customToken: token,
      );
    }

    return WhatsAppVerification(
      status: status,
      uid: uid,
      role: role,
      phoneMasked: masked is String ? masked : '',
    );
  }
}

int _positiveInt(Object? value, {required int fallback}) {
  if (value is int && value > 0) return value;
  if (value is num && value > 0) return value.toInt();
  return fallback;
}
