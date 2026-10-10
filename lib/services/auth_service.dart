
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
      await _students.doc(user.uid).set({
        ...profile.toMap(),
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      return profile;
    } on FirebaseException catch (error) {
      // Keep the Auth account so it can be repaired instead of silently
      // deleting an account after a Firestore failure.
      await _auth.signOut();

      throw AuthException(
        'Your account was created, but the profile could not be saved. '
        'Database error: ${error.code}. Please try again or contact support.',
      );
    }
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
