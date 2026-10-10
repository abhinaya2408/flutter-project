import 'package:college_bakery_flutter/models/student_profile.dart';
import 'package:college_bakery_flutter/screens/bakery_login_screen.dart';
import 'package:college_bakery_flutter/screens/landing_screen.dart';
import 'package:college_bakery_flutter/screens/student_login_screen.dart';
import 'package:college_bakery_flutter/screens/student_register_screen.dart';
import 'package:college_bakery_flutter/state/session_controller.dart';
import 'package:college_bakery_flutter/theme/app_theme.dart';
import 'package:college_bakery_flutter/widgets/app_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

/// A session whose sign-in and sign-up always blow up with a non-`AuthException`
/// error — the shape of a Firebase plugin/network failure.
class _ExplodingSession extends SessionController {
  @override
  Future<StudentProfile> loginStudent({
    required String email,
    required String password,
  }) async =>
      throw StateError('boom');

  @override
  Future<StudentProfile> registerStudent({
    required String fullName,
    required String studentId,
    required String phone,
    required String email,
    required String password,
  }) async =>
      throw StateError('boom');
}

void main() {
  setUpAll(() {
    // The fonts are fetched from Google Fonts at runtime in the real app; the
    // tests must not hit the network.
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// The original pages are desktop-first; the tests render at a width where
  /// the landing page uses its three-column grid.
  void useDesktopSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1280, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Widget wrap(Widget child) {
    return ChangeNotifierProvider<SessionController>(
      create: (_) => SessionController(),
      child: MaterialApp(
        theme: AppTheme.light,
        home: child,
        routes: <String, WidgetBuilder>{
          '/student-login': (_) => const StudentLoginScreen(),
          '/student-register': (_) => const StudentRegisterScreen(),
          '/customize': (_) => const SizedBox.shrink(),
        },
      ),
    );
  }

  group('landing page (index.html)', () {
    testWidgets('renders the hero, sections and every popular cake',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      await tester.pumpWidget(wrap(const LandingScreen()));
      await tester.pump();

      expect(find.text('Your Cake, Your Way.'), findsOneWidget);
      expect(find.text('🎂 College Bakery Ordering'), findsOneWidget);
      expect(find.text('Customize Your Cake'), findsWidgets);
      expect(find.text('Explore Cakes'), findsOneWidget);
      expect(find.text('Get Started'), findsOneWidget);
      expect(find.text('Continue as Student'), findsOneWidget);
      expect(find.text('Bakery Owner'), findsOneWidget);
      expect(find.text('Popular Cakes'), findsWidgets);
      expect(find.text('Chocolate Cake'), findsOneWidget);
      expect(find.text('Strawberry Cake'), findsOneWidget);
      expect(find.text('From ₹550'), findsWidgets);
      // Red Velvet (base 50) and Strawberry (base 50) both start at ₹600.
      expect(find.text('From ₹600'), findsNWidgets(2));
      expect(find.text('How It Works'), findsWidgets);
      expect(find.text('Share Your Idea'), findsOneWidget);
      expect(find.text('Why Order With Us?'), findsOneWidget);
      expect(find.text('Custom Cake Inspiration'), findsOneWidget);
      expect(find.text('What Students Say'), findsOneWidget);
      expect(find.text('Ananya S.'), findsOneWidget);
      expect(
        find.textContaining('© 2026 Crumb & Cream'),
        findsOneWidget,
      );
    });
  });

  group('student sign in (student-login.html)', () {
    testWidgets('shows the demo banner and validates an empty form',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      await tester.pumpWidget(wrap(const StudentLoginScreen()));
      await tester.pump();

      expect(find.text('Welcome back'), findsOneWidget);
      expect(
        find.text('ananya.sharma@yourcollege.edu · demo1234'),
        findsOneWidget,
      );

      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(
        find.text('Please enter a valid email address.'),
        findsOneWidget,
      );
      expect(find.text('Password is required.'), findsOneWidget);
    });

    testWidgets('rejects an email without @', (WidgetTester tester) async {
      useDesktopSurface(tester);
      await tester.pumpWidget(wrap(const StudentLoginScreen()));
      await tester.pump();

      await tester.enterText(find.byType(TextField).first, 'ananya');
      await tester.tap(find.text('Sign In'));
      await tester.pump();

      expect(
        find.text('Please enter a valid email address.'),
        findsOneWidget,
      );
    });
  });

  group('sign-in failures never leave a dead form', () {
    Widget wrapWith(SessionController session, Widget child) {
      return ChangeNotifierProvider<SessionController>.value(
        value: session,
        child: MaterialApp(theme: AppTheme.light, home: child),
      );
    }

    testWidgets('an unexpected error re-enables Sign In and is reported',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      await tester.pumpWidget(
        wrapWith(_ExplodingSession(), const StudentLoginScreen()),
      );
      await tester.pump();

      await tester.enterText(
        find.byType(TextField).at(0),
        'ananya.sharma@yourcollege.edu',
      );
      await tester.enterText(find.byType(TextField).at(1), 'demo1234');
      await tester.tap(find.text('Sign In'));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
      // The button must be tappable again, not stuck in its busy state.
      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('an unexpected error re-enables Create Account',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      await tester.pumpWidget(
        wrapWith(_ExplodingSession(), const StudentRegisterScreen()),
      );
      await tester.pump();

      await tester.enterText(find.byType(TextField).at(0), 'Ananya Sharma');
      await tester.enterText(find.byType(TextField).at(1), 'STU2024010');
      await tester.enterText(find.byType(TextField).at(2), '9876543210');
      await tester.enterText(
        find.byType(TextField).at(3),
        'ananya10@yourcollege.edu',
      );
      await tester.enterText(find.byType(TextField).at(4), 'demo1234');
      await tester.enterText(find.byType(TextField).at(5), 'demo1234');
      await tester.tap(find.text('Create Account'));
      await tester.pumpAndSettle();

      expect(find.text('Something went wrong. Please try again.'), findsOneWidget);
      expect(
        tester.widget<AppButton>(find.byType(AppButton)).onPressed,
        isNotNull,
      );
    });
  });

  group('student registration (student-register.html)', () {
    testWidgets('shows every field error at once',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      await tester.pumpWidget(wrap(const StudentRegisterScreen()));
      await tester.pump();

      expect(find.text('Create your account'), findsOneWidget);
      expect(
        find.textContaining('@yourcollege.edu'),
        findsWidgets,
      );

      await tester.tap(find.text('Create Account'));
      await tester.pump();

      expect(find.text('Full name is required.'), findsOneWidget);
      expect(find.text('Student ID is required.'), findsOneWidget);
      expect(
        find.text('Enter a valid 10-digit phone number.'),
        findsOneWidget,
      );
      expect(
        find.text('Please use your official college email address.'),
        findsOneWidget,
      );
      expect(
        find.text('Password must be at least 6 characters.'),
        findsOneWidget,
      );
      expect(find.text('Passwords do not match.'), findsOneWidget);
    });
  });

  group('bakery sign in (bakery-login.html)', () {
    testWidgets('renders the portal copy and demo account',
        (WidgetTester tester) async {
      useDesktopSurface(tester);
      await tester.pumpWidget(wrap(const BakeryLoginScreen()));
      await tester.pump();

      expect(find.text('Bakery Member Portal'), findsOneWidget);
      expect(
        find.text('owner@collegebakery.com · bakery123'),
        findsOneWidget,
      );
      expect(find.text('Sign In'), findsOneWidget);
    });
  });
}
