import 'package:college_bakery_flutter/services/firebase_emulator.dart';
import 'package:flutter_test/flutter_test.dart';

/// The emulator wiring must stay opt-in.
///
/// Every shipped build — `flutter run`, `flutter build web`, `flutter build apk`
/// — has to talk to the real project. If the compile-time switch were ever
/// turned on by default, that would silently send production traffic to a local
/// emulator, so it is asserted here rather than left to review.
void main() {
  test('emulator connection is off unless the run opts in', () async {
    expect(
      FirebaseEmulator.enabled,
      isFalse,
      reason: 'a normal build must never point at the emulators',
    );

    // With the switch off this must be a no-op: it returns *before* touching
    // `FirebaseFirestore.instance` / `FirebaseAuth.instance`. Under
    // `flutter test` no Firebase app is initialised, so a connection attempt
    // would throw `No Firebase App '[DEFAULT]' has been created` — completing
    // quietly is the proof that nothing was contacted.
    await FirebaseEmulator.connectIfRequested();
  });

  test('the emulator defaults match the suite\'s documented ports', () {
    expect(FirebaseEmulator.host, '127.0.0.1');
    expect(FirebaseEmulator.firestorePort, 8080);
    expect(FirebaseEmulator.authPort, 9099);
  });
}
