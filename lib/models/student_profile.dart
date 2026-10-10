/// A student account profile.
///
/// The web prototype keeps the whole account (including the password) in the
/// `bakery_students` LocalStorage array. In the Flutter app the password lives
/// in Firebase Authentication only, so the Firestore document holds the same
/// profile fields minus the password:
///
/// ```text
/// students/{uid}
///   studentId, fullName, email, phone
/// ```
class StudentProfile {
  const StudentProfile({
    required this.uid,
    required this.studentId,
    required this.fullName,
    required this.email,
    required this.phone,
  });

  /// Firebase Authentication uid (also the Firestore document id).
  final String uid;

  final String studentId;
  final String fullName;
  final String email;
  final String phone;

  /// What the session stores — `setCurrentStudent()` in `js/auth.js` only keeps
  /// these four fields.
  Map<String, String> toSessionMap() => <String, String>{
        'studentId': studentId,
        'fullName': fullName,
        'email': email,
        'phone': phone,
      };

  Map<String, dynamic> toMap() => <String, dynamic>{
        'studentId': studentId,
        'fullName': fullName,
        'email': email,
        'phone': phone,
      };

  factory StudentProfile.fromMap(String uid, Map<String, dynamic> map) =>
      StudentProfile(
        uid: uid,
        studentId: (map['studentId'] ?? '') as String,
        fullName: (map['fullName'] ?? '') as String,
        email: (map['email'] ?? '') as String,
        phone: (map['phone'] ?? '') as String,
      );
}

/// The bakery member session — `setOwnerSession()` in `js/auth.js` stores
/// `{ email, loggedInAt }`.
class BakeryMember {
  const BakeryMember({required this.email, required this.loggedInAt});

  final String email;
  final String loggedInAt;
}
