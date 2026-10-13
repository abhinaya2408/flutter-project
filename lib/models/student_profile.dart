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
    this.phoneE164 = '',
    this.phoneVerified = false,
  });

  /// Firebase Authentication uid (also the Firestore document id).
  final String uid;

  final String studentId;
  final String fullName;
  final String email;

  /// The national contact number the app has always stored (10 digits). Left
  /// untouched by WhatsApp verification so existing orders keep their format.
  final String phone;

  /// The same number in E.164, written by the trusted backend when the student
  /// verifies it on WhatsApp. Never written by the client.
  final String phoneE164;

  /// Set by the trusted backend only. A client write of this field is rejected
  /// by the Firestore rules in `firestore.rules.proposed`.
  final bool phoneVerified;

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
        if (phoneE164.isNotEmpty) 'phoneE164': phoneE164,
        'phoneVerified': phoneVerified,
      };

  factory StudentProfile.fromMap(String uid, Map<String, dynamic> map) =>
      StudentProfile(
        uid: uid,
        studentId: (map['studentId'] ?? '') as String,
        fullName: (map['fullName'] ?? '') as String,
        email: (map['email'] ?? '') as String,
        phone: (map['phone'] ?? '') as String,
        phoneE164: (map['phoneE164'] ?? '') as String,
        phoneVerified: map['phoneVerified'] == true,
      );
}

/// The bakery member session — `setOwnerSession()` in `js/auth.js` stores
/// `{ email, loggedInAt }`.
class BakeryMember {
  const BakeryMember({required this.email, required this.loggedInAt});

  final String email;
  final String loggedInAt;
}
