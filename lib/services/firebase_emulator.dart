import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// The local Firebase emulator suite (Firestore + Authentication).
///
/// **Off by default.** Every switch here is a `bool.fromEnvironment` /
/// `String.fromEnvironment` constant, so a normal build — `flutter run`,
/// `flutter build web`, `flutter build apk` — compiles [connectIfRequested]
/// down to a no-op and the app talks to the real project exactly as before.
/// Nothing in this file runs, and no emulator host is ever contacted, unless
/// the run explicitly asks for it:
///
/// ```bash
/// firebase emulators:start --only auth,firestore
/// flutter run --dart-define=USE_FIREBASE_EMULATOR=true
/// ```
///
/// The emulator suite is what makes the security rules testable: pointed at the
/// emulator, `firestore.rules` from this repository is enforced locally, so a
/// write that the rules forbid fails here instead of only in production.
///
/// A **physical** device cannot see the host machine's `localhost`. Forward the
/// emulator ports over the USB bridge first — that makes `127.0.0.1` on the
/// device reach the host, which is the default [host] below:
///
/// ```bash
/// adb reverse tcp:8080 tcp:8080   # Firestore
/// adb reverse tcp:9099 tcp:9099   # Authentication
/// ```
///
/// An Android emulator instead reaches the host as `10.0.2.2`:
/// `--dart-define=FIREBASE_EMULATOR_HOST=10.0.2.2`.
class FirebaseEmulator {
  FirebaseEmulator._();

  /// `--dart-define=USE_FIREBASE_EMULATOR=true`.
  static const bool enabled = bool.fromEnvironment('USE_FIREBASE_EMULATOR');

  /// `--dart-define=FIREBASE_EMULATOR_HOST=...` (default `127.0.0.1`, which is
  /// the device itself once `adb reverse` is set up).
  static const String host = String.fromEnvironment(
    'FIREBASE_EMULATOR_HOST',
    defaultValue: '127.0.0.1',
  );

  /// `--dart-define=FIREBASE_FIRESTORE_PORT=...`
  static const int firestorePort = int.fromEnvironment(
    'FIREBASE_FIRESTORE_PORT',
    defaultValue: 8080,
  );

  /// `--dart-define=FIREBASE_AUTH_PORT=...`
  static const int authPort = int.fromEnvironment(
    'FIREBASE_AUTH_PORT',
    defaultValue: 9099,
  );

  /// Points Firestore and Authentication at the emulator suite, but only when
  /// the run opted in. Must be called *after* `Firebase.initializeApp`, since
  /// both `use*Emulator` calls act on an initialised app.
  static Future<void> connectIfRequested() async {
    if (!enabled) return;
    await connect();
  }

  /// Points Firestore and Authentication at the emulator suite unconditionally.
  ///
  /// Used by `integration_test/`, which sets its own host and ports instead of
  /// relying on the compile-time switches.
  static Future<void> connect({
    String targetHost = host,
    int targetFirestorePort = firestorePort,
    int targetAuthPort = authPort,
  }) async {
    FirebaseFirestore.instance.useFirestoreEmulator(
      targetHost,
      targetFirestorePort,
    );
    await FirebaseAuth.instance.useAuthEmulator(targetHost, targetAuthPort);
  }
}
