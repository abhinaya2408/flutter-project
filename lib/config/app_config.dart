/// Application configuration — the constants at the top of
/// `college-bakery/js/app.js`, plus the demo accounts that `seedDemoData()`
/// pre-loads.
class AppConfig {
  AppConfig._();

  static const String appTitle = 'Crumb & Cream';
  static const String appTagline = 'Your Cake, Your Way.';
  

  /// `COLLEGE_EMAIL_DOMAIN` in `js/app.js`.
  static const String collegeEmailDomain = '@yourcollege.edu';

  /// The demo bakery account advertised on `bakery-login.html`
  /// (`OWNER_CREDENTIALS` in `js/app.js`). The password lives in Firebase
  /// Authentication; this is only the address used by the seed and the demo
  /// banner.
  static const String demoOwnerEmail = 'owner@collegebakery.com';
  static const String demoOwnerPassword = 'bakery123';

  /// `seedDemoData()` — the three pre-seeded students. Passwords live in
  /// Firebase Authentication.
  static const String demoStudentPassword = 'demo1234';
  static const List<DemoAccount> demoStudents = <DemoAccount>[
    DemoAccount(
      studentId: 'STU2024001',
      fullName: 'Ananya Sharma',
      email: 'ananya.sharma@yourcollege.edu',
      phone: '9876543210',
    ),
    DemoAccount(
      studentId: 'STU2024002',
      fullName: 'Priya Verma',
      email: 'priya.verma@yourcollege.edu',
      phone: '9876543211',
    ),
    DemoAccount(
      studentId: 'STU2024003',
      fullName: 'Rahul Nair',
      email: 'rahul.nair@yourcollege.edu',
      phone: '9876543212',
    ),
  ];

  /// Firebase Storage folder for uploaded reference photos (the original kept
  /// the image inline as a Data URL on the order document).
  static const String referenceImageFolder = 'reference_images';
}

/// A demo account definition used by the seeder.
class DemoAccount {
  const DemoAccount({
    required this.studentId,
    required this.fullName,
    required this.email,
    required this.phone,
  });

  final String studentId;
  final String fullName;
  final String email;
  final String phone;
}
