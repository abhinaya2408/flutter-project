import 'package:flutter/foundation.dart';

import '../models/student_profile.dart';
import '../services/auth_service.dart';

/// Holds the signed-in session.
///
/// The web prototype kept two separate LocalStorage keys
/// (`bakery_current_user` for students and `bakery_owner_session` for the
/// bakery). Exactly one of [student] / [owner] is set at a time, and every
/// student screen reproduces `requireStudent()` by bouncing to the sign-in
/// screen when [student] is null.
class SessionController extends ChangeNotifier {
  /// Created lazily so the controller can be built (and its screens rendered)
  /// without touching Firebase until a sign-in actually happens.
  AuthService? _authService;

  AuthService get _auth => _authService ??= AuthService();

  StudentProfile? _student;
  BakeryMember? _owner;
  bool _restoring = true;

  StudentProfile? get student => _student;
  BakeryMember? get owner => _owner;
  bool get isStudentLoggedIn => _student != null;
  bool get isOwnerLoggedIn => _owner != null;
  bool get isRestoring => _restoring;

  AuthService get authService => _auth;

  /// Restores the session Firebase Authentication persisted (the original read
  /// `bakery_current_user` / `bakery_owner_session` on every page load).
  Future<void> bootstrap() async {
    _restoring = true;
    notifyListeners();
    try {
      final StudentProfile? student = await _auth.restoreStudent();
      if (student != null) {
        _student = student;
        _owner = null;
      } else {
        final BakeryMember? owner = await _auth.restoreOwner();
        _owner = owner;
        _student = null;
      }
    } finally {
      _restoring = false;
      notifyListeners();
    }
  }

  /// `initStudentLoginPage()` — stores the student session.
  Future<StudentProfile> loginStudent({
    required String email,
    required String password,
  }) async {
    final StudentProfile profile = await _auth.loginStudent(
      email: email,
      password: password,
    );
    _student = profile;
    _owner = null;
    notifyListeners();
    return profile;
  }

  /// `initStudentRegisterPage()` — creates the account and signs the student in.
  Future<StudentProfile> registerStudent({
    required String fullName,
    required String studentId,
    required String phone,
    required String email,
    required String password,
  }) async {
    final StudentProfile profile = await _auth.registerStudent(
      fullName: fullName,
      studentId: studentId,
      phone: phone,
      email: email,
      password: password,
    );
    _student = profile;
    _owner = null;
    notifyListeners();
    return profile;
  }

  /// `initOwnerLoginPage()`
  Future<BakeryMember> loginOwner({
    required String email,
    required String password,
  }) async {
    final BakeryMember member = await _auth.loginOwner(
      email: email,
      password: password,
    );
    _owner = member;
    _student = null;
    notifyListeners();
    return member;
  }

  /// `handleStudentLogout()`
  Future<void> logoutStudent() async {
    await _auth.logout();
    _student = null;
    notifyListeners();
  }

  /// `handleOwnerLogout()`
  Future<void> logoutOwner() async {
    await _auth.logout();
    _owner = null;
    notifyListeners();
  }
}
