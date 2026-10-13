import 'dart:async';

import 'package:college_bakery_flutter/models/student_profile.dart';
import 'package:college_bakery_flutter/screens/student_login_screen.dart';
import 'package:college_bakery_flutter/screens/whatsapp_verify_screen.dart';
import 'package:college_bakery_flutter/services/whatsapp_otp_service.dart';
import 'package:college_bakery_flutter/state/session_controller.dart';
import 'package:college_bakery_flutter/theme/app_theme.dart';
import 'package:college_bakery_flutter/utils/validators.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import 'support/fake_otp_backend.dart';

void main() {
  setUpAll(() {
    // The real app fetches these at runtime; tests must not hit the network.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  void useDesktopSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  /// Pumps a couple of frames so a completed Future plus its `setState` render,
  /// without `pumpAndSettle` running the resend countdown all the way down.
  Future<void> flush(WidgetTester tester) async {
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// Lets the toast host finish its timers. `AppToast` keeps a 3.2s timer alive
  /// in the overlay, and a widget test fails if any timer is still pending when
  /// the tree is torn down — so every test that triggers a toast ends here.
  Future<void> drainToasts(WidgetTester tester) async {
    await tester.pump(const Duration(seconds: 4));
    await tester.pump(const Duration(milliseconds: 400));
  }

  Widget host({
    required SessionController session,
    required WhatsAppOtpService service,
  }) {
    return ChangeNotifierProvider<SessionController>.value(
      value: session,
      child: MaterialApp(
        theme: AppTheme.light,
        home: WhatsAppVerifyScreen(service: service),
        routes: <String, WidgetBuilder>{
          '/customize': (_) => const Text('customize-route'),
          '/owner-dashboard': (_) => const Text('owner-dashboard-route'),
          '/student-register': (_) => const Text('student-register-route'),
          '/student-login': (_) => const Text('student-login-route'),
        },
      ),
    );
  }

  Future<void> completePhoneStep(WidgetTester tester) async {
    await tester.enterText(find.byType(TextField).at(1), '9876543210');
    await tester.tap(find.text('Send code on WhatsApp'));
    await flush(tester);
  }

  group('entry point', () {
    testWidgets('the student sign-in screen links to WhatsApp verification',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      await tester.pumpWidget(
        ChangeNotifierProvider<SessionController>.value(
          value: FakeSessionController(),
          child: MaterialApp(
            theme: AppTheme.light,
            home: const StudentLoginScreen(),
            routes: <String, WidgetBuilder>{
              '/whatsapp-verify': (_) => const Text('whatsapp-route'),
              '/student-register': (_) => const Text('register-route'),
              '/customize': (_) => const Text('customize-route'),
            },
          ),
        ),
      );
      await tester.pump();

      expect(find.text('WhatsApp number'), findsOneWidget);
      await tester.tap(find.text('WhatsApp number'));
      await tester.pumpAndSettle();

      expect(find.text('whatsapp-route'), findsOneWidget);
    });
  });

  group('phone step', () {
    testWidgets('renders the WhatsApp sign-in prompt', (WidgetTester tester) async {
      useDesktopSurface(tester);
      final FakeOtpBackend backend = FakeOtpBackend();
      await tester.pumpWidget(
        host(
          session: FakeSessionController(),
          service: WhatsAppOtpService(backend: backend),
        ),
      );
      await tester.pump();

      expect(find.text('Sign in with WhatsApp'), findsOneWidget);
      expect(find.text('Send code on WhatsApp'), findsOneWidget);
      expect(find.textContaining('India'), findsWidgets);
      // Consent copy is required before any code is sent.
      expect(find.textContaining('one-time verification code'), findsOneWidget);
    });

    testWidgets('validates the number without calling the backend',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      final FakeOtpBackend backend = FakeOtpBackend();
      await tester.pumpWidget(
        host(
          session: FakeSessionController(),
          service: WhatsAppOtpService(backend: backend),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Send code on WhatsApp'));
      await tester.pump();

      expect(find.text(Validators.otpPhoneInvalid), findsOneWidget);
      expect(backend.calls, isEmpty);
    });

    testWidgets('sends the normalised E.164 number and shows the code step',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      final FakeOtpBackend backend = FakeOtpBackend();
      backend.response = FakeOtpBackend.sentResponse();

      await tester.pumpWidget(
        host(
          session: FakeSessionController(),
          service: WhatsAppOtpService(backend: backend),
        ),
      );
      await tester.pump();

      await completePhoneStep(tester);

      expect(backend.calls, hasLength(1));
      expect(backend.calls.single.data['phoneNumber'], '+919876543210');
      expect(find.text('Verify code'), findsOneWidget);
      expect(find.textContaining('+91 ••••••3210'), findsWidgets);
      expect(find.textContaining('Resend code in 1:00'), findsOneWidget);

      await drainToasts(tester);
    });

    testWidgets('runs the resend countdown down to zero',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      final FakeOtpBackend backend = FakeOtpBackend();
      backend.response = FakeOtpBackend.sentResponse(resendAfterSeconds: 2);

      await tester.pumpWidget(
        host(
          session: FakeSessionController(),
          service: WhatsAppOtpService(backend: backend),
        ),
      );
      await tester.pump();
      await completePhoneStep(tester);

      expect(find.textContaining('Resend code in 0:02'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.textContaining('Resend code in 0:01'), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Resend code'), findsOneWidget);

      // Resending is allowed once the countdown reaches zero.
      await tester.tap(find.text('Resend code'));
      await flush(tester);
      expect(backend.calls, hasLength(2));

      await drainToasts(tester);
    });

    testWidgets('ignores a second tap while a request is in flight',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      final FakeOtpBackend backend = FakeOtpBackend();
      backend.response = FakeOtpBackend.sentResponse();
      // Hold the request open so the busy state is observable, exactly like a
      // slow network round trip.
      backend.gate = Completer<void>();

      await tester.pumpWidget(
        host(
          session: FakeSessionController(),
          service: WhatsAppOtpService(backend: backend),
        ),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(1), '9876543210');
      await tester.tap(find.text('Send code on WhatsApp'));
      await tester.pump();

      // The button is disabled while the request is running.
      await tester.tap(find.text('Send code on WhatsApp'), warnIfMissed: false);
      await tester.pump();

      expect(backend.calls, hasLength(1));

      backend.gate!.complete();
      await flush(tester);
      expect(backend.calls, hasLength(1));

      await drainToasts(tester);
    });

    testWidgets('surfaces a provider outage and stays on the phone step',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      final FakeOtpBackend backend = FakeOtpBackend();
      backend.queuedErrors.add(
        OtpBackendException(code: 'unavailable', reason: 'provider-unavailable'),
      );

      await tester.pumpWidget(
        host(
          session: FakeSessionController(),
          service: WhatsAppOtpService(backend: backend),
        ),
      );
      await tester.pump();
      await completePhoneStep(tester);

      expect(
        find.text(otpFailureMessage(OtpFailure.providerUnavailable)),
        findsOneWidget,
      );
      // Still on the phone step, and the button works again.
      expect(find.text('Send code on WhatsApp'), findsOneWidget);
    });
  });

  group('code step', () {
    testWidgets('rejects a wrong code and re-enables the form',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      final FakeOtpBackend backend = FakeOtpBackend();
      backend.response = FakeOtpBackend.sentResponse();

      await tester.pumpWidget(
        host(
          session: FakeSessionController(),
          service: WhatsAppOtpService(backend: backend),
        ),
      );
      await tester.pump();
      await completePhoneStep(tester);

      backend.queuedErrors.add(
        OtpBackendException(code: 'invalid-argument', reason: 'invalid-code'),
      );
      await tester.enterText(find.byType(TextField).first, '111111');
      await tester.tap(find.text('Verify code'));
      await flush(tester);

      expect(find.text(otpFailureMessage(OtpFailure.invalidCode)), findsOneWidget);
      expect(backend.calls, hasLength(2));
      expect(backend.calls.last.data['intent'], 'sign_in');

      await drainToasts(tester);
    });

    testWidgets('never submits a code that is not six digits',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      final FakeOtpBackend backend = FakeOtpBackend();
      backend.response = FakeOtpBackend.sentResponse();

      await tester.pumpWidget(
        host(
          session: FakeSessionController(),
          service: WhatsAppOtpService(backend: backend),
        ),
      );
      await tester.pump();
      await completePhoneStep(tester);

      await tester.enterText(find.byType(TextField).first, '12');
      await tester.tap(find.text('Verify code'));
      await tester.pump();

      expect(find.text(Validators.otpCodeInvalid), findsOneWidget);
      // Only the earlier request call happened.
      expect(backend.calls, hasLength(1));

      await drainToasts(tester);
    });

    testWidgets('shows the register path when the number has no account',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      final FakeOtpBackend backend = FakeOtpBackend();
      backend.response = FakeOtpBackend.sentResponse();

      await tester.pumpWidget(
        host(
          session: FakeSessionController(),
          service: WhatsAppOtpService(backend: backend),
        ),
      );
      await tester.pump();
      await completePhoneStep(tester);

      backend.queuedErrors.add(
        OtpBackendException(code: 'not-found', reason: 'no-account'),
      );
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.tap(find.text('Verify code'));
      await flush(tester);

      expect(find.text('No account found for this number'), findsOneWidget);
      expect(find.text('Create an account'), findsOneWidget);

      await drainToasts(tester);
    });
  });

  group('sign in', () {
    testWidgets('signs a student in and opens the student experience',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      final FakeOtpBackend backend = FakeOtpBackend();
      final FakeSessionController session =
          FakeSessionController(signInStudent: testStudent());
      backend.response = FakeOtpBackend.sentResponse();

      await tester.pumpWidget(
        host(session: session, service: WhatsAppOtpService(backend: backend)),
      );
      await tester.pump();
      await completePhoneStep(tester);

      backend.response = FakeOtpBackend.verifiedResponse();
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.tap(find.text('Verify code'));
      await tester.pump();
      // The screen waits 600ms before routing so the success toast is visible.
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 400));

      expect(session.lastCustomToken, 'custom-token-value');
      expect(find.text('customize-route'), findsOneWidget);

      await drainToasts(tester);
    });

    testWidgets('routes a bakery member to the dashboard',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      final FakeOtpBackend backend = FakeOtpBackend();
      final FakeSessionController session = FakeSessionController(
        signInOwner: const BakeryMember(
          email: 'owner@collegebakery.com',
          loggedInAt: '',
        ),
      );
      backend.response = FakeOtpBackend.sentResponse();

      await tester.pumpWidget(
        host(session: session, service: WhatsAppOtpService(backend: backend)),
      );
      await tester.pump();
      await completePhoneStep(tester);

      backend.response = FakeOtpBackend.verifiedResponse(
        role: 'bakery_member',
        uid: 'owner-1',
      );
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.tap(find.text('Verify code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.text('owner-dashboard-route'), findsOneWidget);

      await drainToasts(tester);
    });

    testWidgets('reports a failed session exchange rather than navigating',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      final FakeOtpBackend backend = FakeOtpBackend();
      final FakeSessionController session =
          FakeSessionController(signInStudent: testStudent());
      session.signInThrows = true;
      backend.response = FakeOtpBackend.sentResponse();

      await tester.pumpWidget(
        host(session: session, service: WhatsAppOtpService(backend: backend)),
      );
      await tester.pump();
      await completePhoneStep(tester);

      backend.response = FakeOtpBackend.verifiedResponse();
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.tap(find.text('Verify code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));
      await tester.pump(const Duration(milliseconds: 400));

      expect(
        find.textContaining('missing its student or bakery profile'),
        findsOneWidget,
      );
      expect(find.text('customize-route'), findsNothing);

      await drainToasts(tester);
    });
  });

  group('link mode', () {
    testWidgets('offers verification instead of sign-in for a signed-in student',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      final FakeOtpBackend backend = FakeOtpBackend();
      final FakeSessionController session =
          FakeSessionController(currentStudent: testStudent());
      backend.response = FakeOtpBackend.sentResponse();

      await tester.pumpWidget(
        host(session: session, service: WhatsAppOtpService(backend: backend)),
      );
      await tester.pump();

      expect(find.text('Verify your WhatsApp number'), findsOneWidget);
      expect(find.text('Send code to verify'), findsOneWidget);
    });

    testWidgets('links the number, refreshes the profile and returns',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      final FakeOtpBackend backend = FakeOtpBackend();
      final FakeSessionController session =
          FakeSessionController(currentStudent: testStudent());
      backend.response = FakeOtpBackend.sentResponse();

      final WhatsAppOtpService service = WhatsAppOtpService(backend: backend);

      await tester.pumpWidget(
        ChangeNotifierProvider<SessionController>.value(
          value: session,
          child: MaterialApp(
            theme: AppTheme.light,
            home: Builder(
              builder: (BuildContext context) => Scaffold(
                body: TextButton(
                  onPressed: () =>
                      Navigator.of(context).pushNamed('/whatsapp-verify'),
                  child: const Text('open-verify'),
                ),
              ),
            ),
            routes: <String, WidgetBuilder>{
              '/whatsapp-verify': (_) => WhatsAppVerifyScreen(service: service),
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('open-verify'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField).at(1), '9876543210');
      await tester.tap(find.text('Send code to verify'));
      await flush(tester);

      backend.response = FakeOtpBackend.verifiedResponse(
        status: 'linked',
        customToken: null,
      );
      await tester.enterText(find.byType(TextField).first, '123456');
      await tester.tap(find.text('Verify code'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 800));

      expect(backend.calls.last.data['intent'], 'link');
      expect(session.reloadCount, 1);
      // Returned to the screen that opened it.
      expect(find.text('open-verify'), findsOneWidget);

      await drainToasts(tester);
    });
  });
}
