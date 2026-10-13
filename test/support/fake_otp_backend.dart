import 'dart:async';

import 'package:college_bakery_flutter/models/student_profile.dart';
import 'package:college_bakery_flutter/services/auth_service.dart';
import 'package:college_bakery_flutter/services/whatsapp_otp_service.dart';
import 'package:college_bakery_flutter/state/session_controller.dart';

/// A recorded call to the OTP backend.
typedef BackendCall = ({String function, Map<String, dynamic> data});

/// An [OtpBackend] that never touches Firebase.
///
/// It can be primed with a success payload or with queued failures, so the
/// service's parsing and error mapping are tested against exactly the shapes
/// the Cloud Functions produce — without any network and without a fake
/// *verification* path that could ever run in the shipped app.
class FakeOtpBackend implements OtpBackend {
  final List<BackendCall> calls = <BackendCall>[];
  final List<OtpBackendException> queuedErrors = <OtpBackendException>[];

  /// Returned when no error is queued.
  Map<String, dynamic> response = <String, dynamic>{};

  /// When set, calls block until it completes — used to observe the in-flight
  /// (busy) state of a screen instead of an instant resolution.
  Completer<void>? gate;

  @override
  Future<Map<String, dynamic>> invoke(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    calls.add((function: functionName, data: data));
    final Completer<void>? gate = this.gate;
    if (gate != null) await gate.future;
    if (queuedErrors.isNotEmpty) throw queuedErrors.removeAt(0);
    return response;
  }

  /// The payload for a successful `requestWhatsAppOtp`.
  static Map<String, dynamic> sentResponse({
    String phoneMasked = '+91 ••••••3210',
    int expiresInSeconds = 600,
    int resendAfterSeconds = 60,
  }) =>
      <String, dynamic>{
        'status': 'sent',
        'channel': 'whatsapp',
        'phoneMasked': phoneMasked,
        'expiresInSeconds': expiresInSeconds,
        'resendAfterSeconds': resendAfterSeconds,
      };

  /// The payload for a successful `verifyWhatsAppOtp`.
  static Map<String, dynamic> verifiedResponse({
    String status = 'signed_in',
    String uid = 'uid-1',
    String role = 'student',
    String? customToken = 'custom-token-value',
  }) =>
      <String, dynamic>{
        'status': status,
        'uid': uid,
        'role': role,
        'phoneMasked': '+91 ••••••3210',
        'customToken': ?customToken,
      };
}

/// A [SessionController] with no Firebase behind it, for widget tests.
///
/// `currentStudent` / `currentOwner` model "who is already signed in" (which
/// decides whether the screen signs in or links), while `signInStudent` /
/// `signInOwner` model the account a completed verification resolves to.
class FakeSessionController extends SessionController {
  FakeSessionController({
    this.currentStudent,
    this.currentOwner,
    this.signInStudent,
    this.signInOwner,
  });

  final StudentProfile? currentStudent;
  final BakeryMember? currentOwner;
  final StudentProfile? signInStudent;
  final BakeryMember? signInOwner;

  int reloadCount = 0;
  String? lastCustomToken;
  bool signInThrows = false;

  /// When set, [registerStudent] throws it — modelling a registration whose
  /// Firestore profile write failed after the Auth account was created.
  AuthException? registerFailure;
  int registerCalls = 0;
  int ensureProfileCalls = 0;
  bool ensureProfileSucceeds = true;

  @override
  Future<StudentProfile> registerStudent({
    required String fullName,
    required String studentId,
    required String phone,
    required String email,
    required String password,
  }) async {
    registerCalls += 1;
    final AuthException? failure = registerFailure;
    if (failure != null) throw failure;
    return signInStudent ?? testStudent();
  }

  @override
  Future<StudentProfile> ensureStudentProfile({
    required String fullName,
    required String studentId,
    required String phone,
    required String email,
  }) async {
    ensureProfileCalls += 1;
    if (!ensureProfileSucceeds) throw ProfileWriteFailure('permission-denied');
    return signInStudent ?? testStudent();
  }

  @override
  StudentProfile? get student => currentStudent;

  @override
  BakeryMember? get owner => currentOwner;

  @override
  Future<SessionSignIn> loginWithWhatsAppOtp({required String customToken}) async {
    lastCustomToken = customToken;
    if (signInThrows) {
      throw AuthException('Your account is missing its student or bakery profile.');
    }
    return SessionSignIn(student: signInStudent, owner: signInOwner);
  }

  @override
  Future<StudentProfile?> reloadStudentProfile() async {
    reloadCount += 1;
    return currentStudent;
  }
}

/// A student profile used across the tests.
StudentProfile testStudent({
  String uid = 'uid-1',
  String studentId = 'STU2024001',
  String fullName = 'Ananya Sharma',
  String phone = '9876543210',
  bool phoneVerified = false,
}) =>
    StudentProfile(
      uid: uid,
      studentId: studentId,
      fullName: fullName,
      email: 'ananya.sharma@yourcollege.edu',
      phone: phone,
      phoneVerified: phoneVerified,
    );
