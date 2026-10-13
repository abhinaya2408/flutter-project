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

  // ---------------- Reference photos (Cloudinary) ----------------
  //
  // Cloudinary's *unsigned* upload flow. The cloud name and the upload preset
  // are public by design — an unsigned preset exists precisely so a client can
  // upload without holding a credential — and neither is a secret.
  //
  // NEVER add a Cloudinary API key, API secret or signed-upload credential in
  // this file: anything here ships inside the app. Deleting or overwriting an
  // asset needs a signed call from a trusted backend.

  /// Cloudinary cloud name.
  static const String cloudinaryCloudName = 'haryqfbk';

  /// Unsigned upload preset. It must be configured in the Cloudinary console
  /// as **Unsigned** and must allow images of at most 2 MB.
  static const String cloudinaryUploadPreset = 'crumbly_reference_upload';

  /// Which provider the reference-photo upload uses.
  ///
  /// `true`  → Cloudinary (unsigned upload), the configured provider.
  /// `false` → the previous Firebase Storage path, kept as a switchable
  ///           fallback so the old behaviour can be restored without touching
  ///           any other code.
  static const bool useCloudinaryForReferenceImages = true;

  /// Whether a usable Cloudinary configuration is present.
  static bool get isCloudinaryConfigured =>
      cloudinaryCloudName.trim().isNotEmpty &&
      cloudinaryUploadPreset.trim().isNotEmpty;

  // ---------------- WhatsApp OTP (Firebase Cloud Functions) ----------------
  //
  // These three values are the *only* thing the client knows about the
  // WhatsApp verification backend. There is no provider credential here, and
  // there must never be one: the Twilio call happens in `functions/`.

  /// Region the OTP callables are deployed to. Must match the backend's
  /// `OTP_FUNCTIONS_REGION`.
  static const String otpFunctionsRegion = 'us-central1';

  /// Exported names in `functions/src/index.ts`.
  static const String requestOtpFunction = 'requestWhatsAppOtp';
  static const String verifyOtpFunction = 'verifyWhatsAppOtp';
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
