import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../firebase_options.dart';
import '../state/session_controller.dart';
import 'demo_seed_service.dart';

/// The result of starting up the app.
class BootstrapResult {
  const BootstrapResult({required this.ready, this.errorMessage});

  /// `true` when Firebase is initialised and the app can run.
  final bool ready;

  /// The failure shown on the setup notice when [ready] is `false`.
  final String? errorMessage;
}

/// Startup sequence:
///
/// 1. `Firebase.initializeApp` (the original had no backend at all);
/// 2. `seedDemoData()` — the one-time demo seed guarded by the
///    `app_meta/demo_seed` flag, exactly like `KEYS.SEEDED`;
/// 3. restore the saved session (`bakery_current_user` / `bakery_owner_session`).
class FirebaseBootstrap {
  FirebaseBootstrap._();

  static Future<BootstrapResult> run(SessionController session) async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    } catch (error) {
      debugPrint('Firebase.initializeApp failed: $error');
      return BootstrapResult(
        ready: false,
        errorMessage: _setupMessage(error),
      );
    }

    // `seedDemoData()` — runs once, guarded by the demo seed flag.
    await DemoSeedService().ensureSeeded();

    // Restore the persisted session.
    await session.bootstrap();

    return const BootstrapResult(ready: true);
  }

  /// The notice shown on the setup screen when startup fails.
  ///
  /// Web and desktop builds have no configuration at all, so the platform
  /// error is the actionable one there; otherwise the placeholder notice
  /// applies while `firebase_options.dart` is still unedited.
  static String _setupMessage(Object error) {
    if (DefaultFirebaseOptions.tryCurrentPlatform() == null) return '$error';
    return DefaultFirebaseOptions.isConfigured
        ? '$error'
        : 'This build still uses the placeholder Firebase configuration.';
  }
}
