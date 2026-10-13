
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/student_profile.dart';
import '../utils/validators.dart';
import 'firestore_paths.dart';

/// User-facing authentication failure.
class AuthException implements Exception {
  AuthException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The Firebase Authentication account was created, but its Firestore profile
/// document could not be written.
///
/// The account is deliberately **kept** and the user stays signed in: that is
/// what makes recovery possible. Signing out instead leaves an account the user
/// can neither use nor re-create (the email is already in use), so the
/// registration screen offers to finish the profile with [AuthService
/// .ensureStudentProfile] on the next attempt.
class ProfileWriteFailure extends AuthException {
  ProfileWriteFailure(this.databaseCode)
      : super(
          'Your account was created, but your profile could not be saved '
          '(database error: $databaseCode). Tap the button again to finish '
          'setting it up.',
        );

  /// The Firestore error code, e.g. `permission-denied`.
  final String databaseCode;
}

/// The account a sign-in resolved to. Exactly one of the two is set, matching
/// the `students` / `bakery_members` split used everywhere else.
class SessionSignIn {
  const SessionSignIn({this.student, this.owner});

  final StudentProfile? student;
  final BakeryMember? owner;

  bool get isStudent => student != null;
  bool get isOwner => owner != null;
}

class AuthService {
  AuthService({FirebaseAuth? auth, FirebaseFirestore? firestore})
      : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;

  FirebaseAuth get auth => _auth;

  User? get currentUser => _auth.currentUser;

  CollectionReference<Map<String, dynamic>> get _students =>
      _firestore.collection(FirestorePaths.students);

  CollectionReference<Map<String, dynamic>> get _members =>
      _firestore.collection(FirestorePaths.bakeryMembers);

  // ---------------- STUDENT REGISTRATION ----------------

  Future<StudentProfile> registerStudent({
    required String fullName,
    required String studentId,
    required String phone,
    required String email,
    required String password,
  }) async {
    final normalizedName = fullName.trim();
    final normalizedStudentId = studentId.trim();
    final normalizedPhone = phone.trim();
    final normalizedEmail = email.trim().toLowerCase();

    if (normalizedName.isEmpty ||
        normalizedStudentId.isEmpty ||
        normalizedPhone.isEmpty ||
        normalizedEmail.isEmpty ||
        password.isEmpty) {
      throw AuthException('Please fill in all required fields.');
    }

    UserCredential credential;

    try {
      credential = await _auth.createUserWithEmailAndPassword(
        email: normalizedEmail,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_registerMessage(error));
    }

    final User? user = credential.user;

    if (user == null) {
      throw AuthException('Account creation failed. Please try again.');
    }

    final StudentProfile profile = StudentProfile(
      uid: user.uid,
      studentId: normalizedStudentId,
      fullName: normalizedName,
      email: normalizedEmail,
      phone: normalizedPhone,
    );

    try {
      // Save the profile automatically under the Firebase Auth UID.
      await _writeStudentProfile(user.uid, profile, isRepair: false);

      return profile;
    } on FirebaseException catch (error) {
      // Keep the Auth account and the session so the profile write can simply
      // be retried — see [ProfileWriteFailure].
      throw ProfileWriteFailure(error.code);
    }
  }

  /// Finishes a registration whose profile write failed, or repairs a profile
  /// that went missing, for the account that is **already signed in**.
  ///
  /// Only ever writes under the current user's own uid, and merges rather than
  /// overwrites, so a value the trusted backend has written (for example
  /// `phoneVerified`) is preserved.
  Future<StudentProfile> ensureStudentProfile({
    required String fullName,
    required String studentId,
    required String phone,
    required String email,
  }) async {
    final User? user = _auth.currentUser;

    if (user == null) {
      throw AuthException(
        'Your sign-in expired before your profile could be saved. '
        'Please create your account again.',
      );
    }

    final StudentProfile profile = StudentProfile(
      uid: user.uid,
      studentId: studentId.trim(),
      fullName: fullName.trim(),
      email: email.trim().toLowerCase(),
      phone: phone.trim(),
    );

    try {
      await _writeStudentProfile(user.uid, profile, isRepair: true);
      return profile;
    } on FirebaseException catch (error) {
      throw ProfileWriteFailure(error.code);
    }
  }

  Future<void> _writeStudentProfile(
    String uid,
    StudentProfile profile, {
    required bool isRepair,
  }) {
    final Map<String, dynamic> data = <String, dynamic>{
      ...profile.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
      // A repair must not rewrite the original creation time.
      if (!isRepair) 'createdAt': FieldValue.serverTimestamp(),
    };
    return _students.doc(uid).set(data, SetOptions(merge: isRepair));
  }

  // ---------------- STUDENT LOGIN ----------------

  Future<StudentProfile> loginStudent({
    required String email,
    required String password,
  }) async {
    final UserCredential credential;

    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_loginMessage(error));
    }

    final User? user = credential.user;

    if (user == null) {
      throw AuthException(Validators.incorrectCredentials);
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _students.doc(user.uid).get();

      if (!snapshot.exists || snapshot.data() == null) {
        await _auth.signOut();

        throw AuthException(
          'Your student profile is missing. Please contact support '
          'to restore your account.',
        );
      }

      return StudentProfile.fromMap(user.uid, snapshot.data()!);
    } on AuthException {
      rethrow;
    } on FirebaseException catch (error) {
      await _auth.signOut();

      throw AuthException(_profileMessage(error));
    }
  }

  // ---------------- BAKERY OWNER LOGIN ----------------

  Future<BakeryMember> loginOwner({
    required String email,
    required String password,
  }) async {
    final UserCredential credential;

    try {
      credential = await _auth.signInWithEmailAndPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthException(_loginMessage(error));
    }

    final User? user = credential.user;

    if (user == null) {
      throw AuthException(Validators.incorrectCredentials);
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _members.doc(user.uid).get();

      if (!snapshot.exists) {
        await _auth.signOut();

        throw AuthException(
          'The bakery owner profile is missing. Please contact support.',
        );
      }

      return BakeryMember(
        email: user.email ?? email.trim(),
        loggedInAt: DateTime.now().toUtc().toIso8601String(),
      );
    } on AuthException {
      rethrow;
    } on FirebaseException catch (error) {
      await _auth.signOut();

      throw AuthException(_profileMessage(error));
    }
  }

  // ---------------- WHATSAPP OTP SIGN-IN ----------------

  /// Exchanges the backend's Firebase custom token for a real Firebase session.
  ///
  /// The token is minted by the trusted Cloud Function *after* Twilio confirms
  /// the WhatsApp code, so this is the only step that turns a verified phone
  /// number into an authenticated user. Profile resolution then follows exactly
  /// the same path as a password sign-in, which keeps role routing identical.
  Future<SessionSignIn> signInWithCustomToken(String customToken) async {
    final UserCredential credential;

    try {
      credential = await _auth.signInWithCustomToken(customToken);
    } on FirebaseAuthException catch (error) {
      throw AuthException(_customTokenMessage(error));
    }

    final User? user = credential.user;

    if (user == null) {
      throw AuthException(
        'We could not complete your WhatsApp sign-in. Please try again.',
      );
    }

    try {
      final DocumentSnapshot<Map<String, dynamic>> studentSnapshot =
          await _students.doc(user.uid).get();

      if (studentSnapshot.exists && studentSnapshot.data() != null) {
        return SessionSignIn(
          student: StudentProfile.fromMap(user.uid, studentSnapshot.data()!),
        );
      }

      final DocumentSnapshot<Map<String, dynamic>> memberSnapshot =
          await _members.doc(user.uid).get();

      if (memberSnapshot.exists) {
        return SessionSignIn(
          owner: BakeryMember(
            email: user.email ?? '',
            loggedInAt: DateTime.now().toUtc().toIso8601String(),
          ),
        );
      }

      // A verified number must never open a session for an account that has no
      // profile: there would be nothing to route it to.
      await _auth.signOut();
      throw AuthException(
        'Your account is missing its student or bakery profile. '
        'Please contact support.',
      );
    } on AuthException {
      rethrow;
    } on FirebaseException catch (error) {
      await _auth.signOut();
      throw AuthException(_profileMessage(error));
    }
  }

  // ---------------- SESSION RESTORATION ----------------

  Future<StudentProfile?> restoreStudent() async {
    final User? user = _auth.currentUser;

    if (user == null) return null;

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _students.doc(user.uid).get();

      if (!snapshot.exists || snapshot.data() == null) {
        return null;
      }

      return StudentProfile.fromMap(user.uid, snapshot.data()!);
    } on FirebaseException {
      return null;
    }
  }

  Future<BakeryMember?> restoreOwner() async {
    final User? user = _auth.currentUser;

    if (user == null) return null;

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _members.doc(user.uid).get();

      if (!snapshot.exists) return null;

      return BakeryMember(
        email: user.email ?? '',
        loggedInAt: DateTime.now().toUtc().toIso8601String(),
      );
    } on FirebaseException {
      return null;
    }
  }

  // ---------------- LOGOUT ----------------

  Future<void> logout() => _auth.signOut();

  // ---------------- STUDENT ID CHECK ----------------

  /// This query requires suitable Firestore rules or a trusted backend.
  /// It returns false on a database error, so do not use it as a security
  /// guarantee for student ID uniqueness.
  Future<bool> studentIdExists(String studentId) async {
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _students
          .where('studentId', isEqualTo: studentId.trim())
          .limit(1)
          .get();

      return snapshot.docs.isNotEmpty;
    } on FirebaseException {
      return false;
    }
  }

  // ---------------- ERROR MESSAGES ----------------

  String _loginMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
      case 'invalid-login-credentials':
      case 'user-disabled':
        return Validators.incorrectCredentials;

      case 'invalid-email':
        return Validators.emailRequired;

      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';

      case 'network-request-failed':
        return Validators.networkUnavailable;

      default:
        return error.message ?? Validators.incorrectCredentials;
    }
  }

  String _customTokenMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'invalid-custom-token':
      case 'custom-token-mismatch':
        return 'Your WhatsApp verification expired. Please verify your number again.';

      case 'network-request-failed':
        return Validators.networkUnavailable;

      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';

      default:
        return 'We could not complete your WhatsApp sign-in. Please try again.';
    }
  }

  String _profileMessage(FirebaseException error) {
    switch (error.code) {
      case 'permission-denied':
        return 'Database permission denied. Please check Firestore rules.';

      case 'unavailable':
        return Validators.networkUnavailable;

      default:
        return 'Could not load your account (${error.code}). '
            'Please try again.';
    }
  }

  String _registerMessage(FirebaseAuthException error) {
    switch (error.code) {
      case 'email-already-in-use':
        return Validators.emailAlreadyExists;

      case 'weak-password':
        return Validators.passwordTooShort;

      case 'invalid-email':
        return Validators.emailRequired;

      case 'operation-not-allowed':
        return 'Email/password registration is disabled in Firebase.';

      case 'network-request-failed':
        return Validators.networkUnavailable;

      case 'too-many-requests':
        return 'Too many attempts. Please wait and try again.';

      default:
        return error.message ?? 'Registration failed. Please try again.';
    }
  }
}
