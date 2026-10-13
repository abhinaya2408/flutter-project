import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;

/// Firebase configuration for the Crumb & Cream app (project `bakeflow-20fb9`).
///
/// `android` and `ios` hold real, working values.
///
/// `web` is what the **Flutter Web / PWA** build needs. A browser is a separate
/// Firebase *app registration* with its own App ID and browser API key, so it
/// cannot reuse the Android or iOS values. Fill the two placeholders in [web]
/// from either:
///
/// ```bash
/// dart pub global activate flutterfire_cli
/// flutterfire configure --project=bakeflow-20fb9 --platforms=web
/// ```
///
/// or, in the Firebase console, ⚙ **Project settings → Your apps → Web (</>)**
/// → *SDK setup and configuration* → copy the `firebaseConfig` fields.
///
/// While `web` still holds placeholders, `isConfigured` is `false` on the web,
/// so the app opens the setup notice instead of the landing page (see
/// `FirebaseBootstrap.run`). Android and iOS are unaffected. Full steps:
/// `docs/WEB_DEPLOYMENT.md`.
///
/// None of these strings is a secret: Firebase client configuration is designed
/// to ship inside the app. Access is enforced by `firestore.rules` and
/// `storage.rules`, never by hiding them. A *service account* key, by contrast,
/// is a real secret and must never be committed.
class DefaultFirebaseOptions {
  DefaultFirebaseOptions._();

  /// The configuration for the current platform, or `null` when this build has
  /// none — only Android, iOS and web are configured.
  ///
  /// Unlike [currentPlatform] this never throws, so startup can fall back to
  /// the setup notice instead of failing before the first frame.
  static FirebaseOptions? tryCurrentPlatform() {
    try {
      return currentPlatform;
    } on UnsupportedError {
      return null;
    }
  }

  /// `true` while this file still holds the placeholder values **and** the
  /// current platform has a configuration at all.
  static bool get isConfigured {
    final FirebaseOptions? options = tryCurrentPlatform();
    return options != null && options.apiKey != _placeholderApiKey;
  }

  /// The value `flutterfire configure` overwrites.
  static const String _placeholderApiKey = 'REPLACE_WITH_YOUR_API_KEY';

  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      // The Flutter Web / PWA build — needs the Web app registration, see [web].
      return web;
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        return ios;
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
      case TargetPlatform.linux:
      case TargetPlatform.fuchsia:
        throw UnsupportedError(
          'DefaultFirebaseOptions have not been configured for '
          '${defaultTargetPlatform.name}.',
        );
    }
  }

  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyAFrxjKr8OpWrJssJH1Hj1eLyaeAyA-qw8',
    appId: '1:606802822852:android:9efe09d2b501236770ab91',
    messagingSenderId: '606802822852',
    projectId: 'bakeflow-20fb9',
    storageBucket: 'bakeflow-20fb9.firebasestorage.app',
  );
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: 'AIzaSyDbbv0BnyER1bVMRA0K95ncghrcismv8yU',
    appId: '1:606802822852:ios:af27588c70305eb770ab91',
    messagingSenderId: '606802822852',
    projectId: 'bakeflow-20fb9',
    storageBucket: 'bakeflow-20fb9.firebasestorage.app',
    iosBundleId: 'com.crumbandcream.collegeBakeryFlutter',
  );

  /// Web (Flutter Web / PWA) configuration.
  ///
  /// `projectId`, `messagingSenderId`, `authDomain` and `storageBucket` are
  /// properties of the Firebase project itself and are already correct.
  ///
  /// `apiKey` and `appId` belong to the **Web app registration** and must be
  /// copied from it — they are the two placeholders below. Until they are real,
  /// the web build shows the setup notice.
  ///
  /// `authDomain` is the domain Firebase Authentication uses. The Hosting domain
  /// (`bakeflow-20fb9.web.app` and `bakeflow-20fb9.firebaseapp.com`) is on the
  /// Authorized-domains list by default; any custom domain added later must be
  /// added there too, or sign-in fails with `auth/unauthorized-domain`.
  static const FirebaseOptions web = FirebaseOptions(
    apiKey: 'AIzaSyA2Xq_BzrN12TKveMhUNvt-Kk-7kAQjtE4',
    appId: '1:606802822852:web:1999258d25e844a870ab91',
    messagingSenderId: '606802822852',
    projectId: 'bakeflow-20fb9',
    authDomain: 'bakeflow-20fb9.firebaseapp.com',
    storageBucket: 'bakeflow-20fb9.firebasestorage.app',
    measurementId: 'G-431R7HZEBK',
  );
}
