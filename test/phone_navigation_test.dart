import 'package:college_bakery_flutter/main.dart';
import 'package:college_bakery_flutter/services/firebase_bootstrap.dart';
import 'package:college_bakery_flutter/state/session_controller.dart';
import 'package:college_bakery_flutter/widgets/app_navbar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  /// 448x997 logical — the Pixel_8_Pro emulator the app runs on
  /// (1344x2992 physical @ 3.0x).
  void usePhoneSurface(WidgetTester tester) {
    tester.view.physicalSize = const Size(1344, 2992);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpApp(WidgetTester tester) async {
    usePhoneSurface(tester);
    await tester.pumpWidget(
      CrumbAndCreamApp(
        bootstrap: const BootstrapResult(ready: true),
        session: SessionController(),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('phone: hero CTA opens student login',
      (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('Your Cake, Your Way.'), findsOneWidget);

    await tester.tap(find.text('Customize Your Cake').first);
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('phone: hamburger menu opens student login',
      (WidgetTester tester) async {
    await pumpApp(tester);

    // Collapsed navbar = brand InkWell + hamburger InkWell.
    final Finder navInkWells = find.descendant(
      of: find.byType(AppNavBar),
      matching: find.byType(InkWell),
    );
    expect(navInkWells, findsNWidgets(2));

    await tester.tap(navInkWells.at(1));
    await tester.pumpAndSettle();

    expect(find.text('Student Login'), findsOneWidget);
    await tester.tap(find.text('Student Login'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('phone: footer Create Account opens registration',
      (WidgetTester tester) async {
    await pumpApp(tester);

    final Finder link = find.text('Create Account').first;
    await tester.scrollUntilVisible(link, 400);
    await tester.tap(link);
    await tester.pumpAndSettle();

    expect(find.text('Create your account'), findsOneWidget);
  });

  testWidgets('phone: landing page lays out without overflow',
      (WidgetTester tester) async {
    await pumpApp(tester);

    // Walk the whole page so every lazily-built section is laid out.
    await tester.scrollUntilVisible(
      find.textContaining('© 2026 Crumb & Cream'),
      600,
    );
    await tester.pumpAndSettle();
  });
}
