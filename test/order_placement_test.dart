import 'package:college_bakery_flutter/screens/student_register_screen.dart';
import 'package:college_bakery_flutter/services/auth_service.dart';
import 'package:college_bakery_flutter/services/order_service.dart';
import 'package:college_bakery_flutter/state/session_controller.dart';
import 'package:college_bakery_flutter/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'support/fake_otp_backend.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  group('OrderPlacementGuard', () {
    test('blocks when there is no student profile', () {
      expect(
        OrderPlacementGuard.blockReason(studentUid: null, authUid: 'uid-1'),
        contains('Please sign in'),
      );
      expect(
        OrderPlacementGuard.blockReason(studentUid: '', authUid: 'uid-1'),
        isNotNull,
      );
    });

    test('blocks when the Firebase Auth session is gone', () {
      // The case that produced `permission-denied`: a restored profile with no
      // Auth credential behind it.
      expect(
        OrderPlacementGuard.blockReason(studentUid: 'uid-1', authUid: null),
        contains('sign-in has expired'),
      );
      expect(
        OrderPlacementGuard.blockReason(studentUid: 'uid-1', authUid: ''),
        isNotNull,
      );
    });

    test('blocks when the profile belongs to another account', () {
      expect(
        OrderPlacementGuard.blockReason(studentUid: 'uid-1', authUid: 'uid-2'),
        contains('does not belong to the signed-in account'),
      );
    });

    test('allows only a matching profile and session', () {
      expect(
        OrderPlacementGuard.blockReason(studentUid: 'uid-1', authUid: 'uid-1'),
        isNull,
      );
    });
  });

  group('ProfileWriteFailure', () {
    test('is an AuthException that says what to do next', () {
      final ProfileWriteFailure failure = ProfileWriteFailure('permission-denied');

      expect(failure, isA<AuthException>());
      expect(failure.databaseCode, 'permission-denied');
      expect(failure.message, contains('permission-denied'));
      expect(failure.message, contains('Tap the button again'));
    });
  });

  group('registration partial failure', () {
    void useDesktopSurface(WidgetTester tester) {
      tester.view.physicalSize = const Size(1280, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
    }

    /// Lets the toast host's timers finish; a pending timer fails a widget test.
    Future<void> drainToasts(WidgetTester tester) async {
      await tester.pump(const Duration(seconds: 4));
      await tester.pump(const Duration(milliseconds: 400));
    }

    Widget wrap(SessionController session) {
      return ChangeNotifierProvider<SessionController>.value(
        value: session,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const StudentRegisterScreen(),
          routes: <String, WidgetBuilder>{
            '/customize': (_) => const Text('customize-route'),
            '/student-login': (_) => const Text('student-login-route'),
          },
        ),
      );
    }

    Future<void> fillForm(WidgetTester tester) async {
      await tester.enterText(find.byType(TextField).at(0), 'Ananya Sharma');
      await tester.enterText(find.byType(TextField).at(1), 'STU2024010');
      await tester.enterText(find.byType(TextField).at(2), '9876543210');
      await tester.enterText(
        find.byType(TextField).at(3),
        'ananya10@yourcollege.edu',
      );
      await tester.enterText(find.byType(TextField).at(4), 'demo1234');
      await tester.enterText(find.byType(TextField).at(5), 'demo1234');
    }

    testWidgets('a failed profile write is reported and can be finished',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      final FakeSessionController session =
          FakeSessionController(signInStudent: testStudent());
      session.registerFailure = ProfileWriteFailure('permission-denied');

      await tester.pumpWidget(wrap(session));
      await tester.pump();
      await fillForm(tester);

      await tester.tap(find.text('Create Account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(session.registerCalls, 1);
      expect(find.textContaining('profile could not be saved'), findsOneWidget);
      // The form is not left dead, and the next step is explicit.
      expect(find.text('Finish Setting Up Profile'), findsOneWidget);

      // Finishing the profile must not try to create a second account.
      await tester.tap(find.text('Finish Setting Up Profile'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 400));

      expect(session.registerCalls, 1);
      expect(session.ensureProfileCalls, 1);
      expect(find.text('customize-route'), findsOneWidget);

      await drainToasts(tester);
    });

    testWidgets('an ordinary successful registration still navigates straight in',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      final FakeSessionController session =
          FakeSessionController(signInStudent: testStudent());

      await tester.pumpWidget(wrap(session));
      await tester.pump();
      await fillForm(tester);

      await tester.tap(find.text('Create Account'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));
      await tester.pump(const Duration(milliseconds: 400));

      expect(session.registerCalls, 1);
      expect(session.ensureProfileCalls, 0);
      expect(find.text('customize-route'), findsOneWidget);

      await drainToasts(tester);
    });
  });
}
