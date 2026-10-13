import 'package:cloud_functions/cloud_functions.dart';

import '../config/app_config.dart';
import '../models/otp_verification.dart';

/// Why a WhatsApp verification step failed, in terms the UI can act on.
enum OtpFailure {
  invalidRequest,
  invalidPhone,
  invalidCode,
  codeExpired,
  rateLimited,
  tooManyAttempts,
  noAccount,
  noProfile,
  phoneInUse,
  providerUnavailable,
  notConfigured,
  unauthenticated,
  network,
  unknown;

  /// Maps the backend's machine-readable `reason` onto a failure.
  static OtpFailure fromReason(Object? reason) {
    switch (reason) {
      case 'invalid-request':
        return OtpFailure.invalidRequest;
      case 'invalid-phone':
        return OtpFailure.invalidPhone;
      case 'invalid-code':
        return OtpFailure.invalidCode;
      case 'code-expired':
        return OtpFailure.codeExpired;
      case 'rate-limited':
        return OtpFailure.rateLimited;
      case 'too-many-attempts':
        return OtpFailure.tooManyAttempts;
      case 'no-account':
        return OtpFailure.noAccount;
      case 'no-profile':
        return OtpFailure.noProfile;
      case 'phone-in-use':
        return OtpFailure.phoneInUse;
      case 'provider-unavailable':
        return OtpFailure.providerUnavailable;
      case 'not-configured':
        return OtpFailure.notConfigured;
      case 'unauthenticated':
        return OtpFailure.unauthenticated;
      default:
        return OtpFailure.unknown;
    }
  }
}

/// Short, user-facing copy for each failure. Kept in one place so the screens
/// never invent their own wording for a server-side reason.
String otpFailureMessage(OtpFailure failure) {
  switch (failure) {
    case OtpFailure.invalidRequest:
      return 'That request could not be completed. Please try again.';
    case OtpFailure.invalidPhone:
      return 'Enter a valid phone number, including the country code.';
    case OtpFailure.invalidCode:
      return 'That code is not correct. Check the WhatsApp message and try again.';
    case OtpFailure.codeExpired:
      return 'That code has expired. Request a new one.';
    case OtpFailure.rateLimited:
      return 'Too many code requests. Please wait a moment and try again.';
    case OtpFailure.tooManyAttempts:
      return 'Too many incorrect attempts. Request a new code.';
    case OtpFailure.noAccount:
      return 'No Crumb & Cream account uses this WhatsApp number yet.';
    case OtpFailure.noProfile:
      return 'Your account is missing its student or bakery profile.';
    case OtpFailure.phoneInUse:
      return 'This WhatsApp number is already linked to a different account.';
    case OtpFailure.providerUnavailable:
      return 'We could not reach WhatsApp right now. Please try again in a moment.';
    case OtpFailure.notConfigured:
      return 'WhatsApp verification is not available yet. Please sign in with your college email.';
    case OtpFailure.unauthenticated:
      return 'Please sign in before linking a WhatsApp number.';
    case OtpFailure.network:
      return 'You appear to be offline. Check your connection and try again.';
    case OtpFailure.unknown:
      return 'Something went wrong. Please try again.';
  }
}

/// A failed WhatsApp verification step, safe to show to the user.
class OtpException implements Exception {
  OtpException(
    this.failure, {
    this.retryAfterSeconds,
    this.code,
    String? message,
  }) : message = message ?? otpFailureMessage(failure);

  final OtpFailure failure;

  /// Set for rate limits, so the screen can start its resend countdown.
  final int? retryAfterSeconds;

  /// The raw `FirebaseFunctionsException` code, for debug logs only.
  final String? code;

  final String message;

  @override
  String toString() => 'OtpException($failure): $message';
}

/// Transport-level failure raised by an [OtpBackend].
///
/// Keeps the service independent of `cloud_functions`, which is what lets the
/// whole flow be tested with a fake backend and no Firebase.
class OtpBackendException implements Exception {
  OtpBackendException({required this.code, this.reason, this.retryAfterSeconds});

  /// The callable error code, e.g. `resource-exhausted`.
  final String code;

  /// The backend's machine-readable reason, when it sent one.
  final String? reason;

  final int? retryAfterSeconds;

  @override
  String toString() => 'OtpBackendException($code, reason: $reason)';
}

/// Where the OTP callables live. Injectable so tests need no Firebase.
abstract class OtpBackend {
  Future<Map<String, dynamic>> invoke(
    String functionName,
    Map<String, dynamic> data,
  );
}

/// The real backend: Firebase Cloud Functions callables. Callable Functions
/// attach the caller's ID token automatically, which is how the `link` intent
/// is authenticated — the client never sends a uid.
class FunctionsOtpBackend implements OtpBackend {
  FunctionsOtpBackend({this.region = AppConfig.otpFunctionsRegion, this.functions});

  final String region;

  /// Injected in tests; otherwise the region-scoped Firebase instance is used.
  final FirebaseFunctions? functions;

  FirebaseFunctions get _instance =>
      functions ?? FirebaseFunctions.instanceFor(region: region);

  @override
  Future<Map<String, dynamic>> invoke(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    final HttpsCallableResult<dynamic> result;
    try {
      result = await _instance.httpsCallable(functionName).call(data);
    } on FirebaseFunctionsException catch (error) {
      throw _translate(error);
    }

    final Object? payload = result.data;
    if (payload is Map) return Map<String, dynamic>.from(payload);
    // A response we cannot read must never be treated as success.
    throw OtpBackendException(code: 'malformed-response');
  }

  OtpBackendException _translate(FirebaseFunctionsException error) {
    final Object? details = error.details;
    final Map<String, dynamic> map =
        details is Map ? Map<String, dynamic>.from(details) : <String, dynamic>{};
    final Object? retry = map['retryAfterSeconds'];

    return OtpBackendException(
      code: error.code,
      reason: map['reason'] is String ? map['reason'] as String : null,
      retryAfterSeconds: retry is num ? retry.toInt() : null,
    );
  }
}

/// The WhatsApp OTP client. No provider secret, and no code, ever passes
/// through this class — it only calls the trusted backend and parses results.
class WhatsAppOtpService {
  WhatsAppOtpService({OtpBackend? backend})
      : _backend = backend ?? FunctionsOtpBackend();

  final OtpBackend _backend;

  /// Ask the backend to send a one-time code over WhatsApp.
  Future<OtpChallenge> requestCode({
    required String phoneE164,
    String? locale,
  }) async {
    final Map<String, dynamic> data = <String, dynamic>{
      'phoneNumber': phoneE164,
      'locale': ?locale,
    };

    try {
      final Map<String, dynamic> result =
          await _backend.invoke(AppConfig.requestOtpFunction, data);
      return OtpChallenge.fromMap(result);
    } on OtpBackendException catch (error) {
      throw _map(error);
    } on FormatException {
      throw OtpException(OtpFailure.unknown);
    }
  }

  /// Check a code for a signed-out caller and return a Firebase custom token.
  Future<WhatsAppVerification> verifyCode({
    required String phoneE164,
    required String code,
  }) =>
      _verify(phoneE164: phoneE164, code: code, intent: OtpIntent.signIn);

  /// Check a code and attach the number to the caller's own account.
  /// Requires an authenticated session; the backend reads the uid from the
  /// request's ID token.
  Future<WhatsAppVerification> linkNumber({
    required String phoneE164,
    required String code,
  }) =>
      _verify(phoneE164: phoneE164, code: code, intent: OtpIntent.link);

  Future<WhatsAppVerification> _verify({
    required String phoneE164,
    required String code,
    required OtpIntent intent,
  }) async {
    final Map<String, dynamic> data = <String, dynamic>{
      'phoneNumber': phoneE164,
      'code': code,
      'intent': intent.wire,
    };

    try {
      final Map<String, dynamic> result =
          await _backend.invoke(AppConfig.verifyOtpFunction, data);
      return WhatsAppVerification.fromMap(result);
    } on OtpBackendException catch (error) {
      throw _map(error);
    } on FormatException {
      throw OtpException(OtpFailure.unknown);
    }
  }

  /// Translate a transport failure into an [OtpException] with user copy,
  /// preferring the backend's explicit reason over the HTTP-ish code.
  OtpException _map(OtpBackendException error) {
    OtpFailure failure = OtpFailure.fromReason(error.reason);
    if (failure == OtpFailure.unknown) {
      failure = _fromCode(error.code);
    }
    return OtpException(
      failure,
      retryAfterSeconds: error.retryAfterSeconds,
      code: error.code,
    );
  }

  OtpFailure _fromCode(String code) {
    switch (code) {
      case 'unavailable':
      case 'deadline-exceeded':
      case 'internal':
        return OtpFailure.providerUnavailable;
      case 'resource-exhausted':
        return OtpFailure.rateLimited;
      case 'unauthenticated':
        return OtpFailure.unauthenticated;
      case 'not-found':
        return OtpFailure.noAccount;
      case 'already-exists':
        return OtpFailure.phoneInUse;
      case 'failed-precondition':
        return OtpFailure.noProfile;
      case 'invalid-argument':
        return OtpFailure.invalidRequest;
      case 'malformed-response':
        return OtpFailure.unknown;
      default:
        return OtpFailure.unknown;
    }
  }
}
