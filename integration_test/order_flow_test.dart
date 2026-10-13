// End-to-end order-flow test against the **local Firebase emulator suite**.
//
// Why it exists: the live project rejected every order write with
// `permission-denied`, and the deployed ruleset does not match the
// `firestore.rules` in this repository. Rather than guess, this test runs the
// app's real services against the emulator, which *does* enforce the ruleset in
// this repository, and proves the whole path: create an account, save the
// profile, issue an order number, save the order, read it back through the same
// query `MyOrdersScreen` uses, and confirm an anonymous write is refused.
//
// It is deliberately *not* part of `flutter test` — it needs the emulators, so
// it lives in `integration_test/` and is run explicitly:
//
//   firebase emulators:start --only auth,firestore
//   flutter test integration_test/order_flow_test.dart -d <device>
//
// On a physical Android device, forward the ports first (see README /
// `docs/ORDER_PLACEMENT.md`):
//
//   adb reverse tcp:8080 tcp:8080
//   adb reverse tcp:9099 tcp:9099
//
// Android debug builds reach the emulator hosts through
// `android/app/src/debug/res/xml/network_security_config.xml`, which permits
// cleartext for `10.0.2.2` / `127.0.0.1` / `localhost` and nothing else.
//
// Nothing here touches the production project: `FirebaseEmulator.connect` is
// called directly and points Firestore and Authentication at a local host.

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';

import 'package:college_bakery_flutter/data/order_status.dart';
import 'package:college_bakery_flutter/firebase_options.dart';
import 'package:college_bakery_flutter/models/order.dart';
import 'package:college_bakery_flutter/models/student_profile.dart';
import 'package:college_bakery_flutter/screens/my_orders_screen.dart';
import 'package:college_bakery_flutter/services/auth_service.dart';
import 'package:college_bakery_flutter/services/firebase_emulator.dart';
import 'package:college_bakery_flutter/services/order_service.dart';
import 'package:college_bakery_flutter/state/session_controller.dart';
import 'package:college_bakery_flutter/theme/app_theme.dart';

/// `--dart-define=FIREBASE_EMULATOR_HOST=...`. Needed for a physical device,
/// which has to reach the host's **LAN** address; the defaults below cover the
/// two local cases.
const String hostOverride = String.fromEnvironment('FIREBASE_EMULATOR_HOST');

/// Where the emulator suite is reachable from the device running this test.
///
///  * an Android emulator sees the host's loopback as `10.0.2.2`;
///  * the desktop and the iOS simulator see it as `127.0.0.1`;
///  * a physical Android device needs the override plus `adb reverse` (or the
///    host's LAN address), because `127.0.0.1` there is the phone itself.
///
/// Resolved here rather than relying on the app's default: a test that silently
/// talks to the wrong host only reports "the client is offline".
String get emulatorHost {
  if (hostOverride.isNotEmpty) return hostOverride;
  if (Platform.isAndroid) return '10.0.2.2';
  return '127.0.0.1';
}

/// Everything this run creates is keyed by the run id, so repeated runs against
/// the same emulator can never collide with a previous run's data.
final String runId = DateTime.now().millisecondsSinceEpoch.toString();
final String testEmail = 'emu.student.$runId@example.com';
final String testStudentId = 'STU-$runId';
const String testPassword = 'EmuTest123!';

StudentProfile? registered;
final List<String> placedOrderIds = <String>[];

Order buildOrder({required String orderId, required StudentProfile student}) {
  final String now = DateTime.now().toUtc().toIso8601String();
  return Order(
    orderId: orderId,
    studentId: student.studentId,
    studentName: student.fullName,
    studentEmail: student.email,
    studentPhone: student.phone,
    flavor: 'Chocolate',
    cakeType: 'Egg',
    size: '1 kg (Medium)',
    cream: 'Chocolate Truffle',
    decorations: const <String>['Sprinkles', 'Cherries'],
    cakeMessage: 'Happy Birthday',
    specialInstructions: 'Less sweet please',
    // The order is placed without a photo here: the upload itself is covered by
    // `test/cloudinary_image_service_test.dart`, and the Cloudinary preset
    // cannot be verified without the console.
    referenceImage: '',
    requiredDate: '2099-01-15',
    requiredTime: '17:30',
    estimatedPrice: 950,
    status: OrderStatus.pending,
    createdAt: now,
    updatedAt: now,
  );
}

/// Pumps the widget tree until [finder] matches, so a real Firestore stream has
/// time to deliver its first snapshot.
Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final DateTime deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    if (finder.evaluate().isNotEmpty) return;
    await tester.pump(const Duration(milliseconds: 200));
    await Future<void>.delayed(const Duration(milliseconds: 200));
  }
  fail('Timed out waiting for $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    GoogleFonts.config.allowRuntimeFetching = false;

    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Point at the emulators.
    await FirebaseEmulator.connect(targetHost: emulatorHost);
    debugPrint(
      'integration_test: emulator host $emulatorHost '
      '(${FirebaseEmulator.firestorePort}/'
      '${FirebaseEmulator.authPort})',
    );

    // Fail loudly and early if the suite is not actually there, instead of
    // reporting a confusing permission error later.
    await FirebaseFirestore.instance
        .collection('app_meta')
        .doc('emulator_probe')
        .get();
  });

  tearDownAll(() async {
    await FirebaseAuth.instance.signOut();
  });

  test('registering a student creates the Auth account and its profile', () async {
    final AuthService auth = AuthService();

    final StudentProfile profile = await auth.registerStudent(
      fullName: 'Emulator Student',
      studentId: testStudentId,
      phone: '9876500000',
      email: testEmail,
      password: testPassword,
    );
    registered = profile;

    expect(profile.uid, isNotEmpty);
    expect(FirebaseAuth.instance.currentUser?.uid, profile.uid);

    final DocumentSnapshot<Map<String, dynamic>> stored =
        await FirebaseFirestore.instance
            .collection('students')
            .doc(profile.uid)
            .get();

    expect(stored.exists, isTrue, reason: 'students/{uid} profile document');
    expect(stored.data()!['studentId'], testStudentId);
    expect(stored.data()!['fullName'], 'Emulator Student');
    expect(stored.data()!['email'], testEmail);
    expect(stored.data()!['phone'], '9876500000');
  });

  test('a placed order is saved and appears in My Orders', () async {
    final StudentProfile student = registered!;
    final OrderService orders = OrderService();

    final String orderId = await orders.generateOrderId();
    placedOrderIds.add(orderId);

    // The counter reserves ids above the demo records and above the CK1024 the
    // old fallback returned.
    expect(orderId, startsWith('CK2'));

    await orders.createOrder(buildOrder(orderId: orderId, student: student));

    // Saved, exactly as the model serialises it.
    final Order? saved = await orders.fetchOrder(orderId);
    expect(saved, isNotNull);
    expect(saved!.orderId, orderId);
    expect(saved.studentId, student.studentId);
    expect(saved.flavor, 'Chocolate');
    expect(saved.estimatedPrice, 950);
    expect(saved.status, OrderStatus.pending);

    // Read back through the very query MyOrdersScreen watches.
    final List<Order> history = await orders
        .watchStudentOrders(student.studentId)
        .firstWhere(
          (List<Order> list) =>
              list.any((Order order) => order.orderId == orderId),
        )
        .timeout(const Duration(seconds: 30));

    expect(history.map((Order order) => order.orderId), contains(orderId));
  });

  testWidgets('My Orders renders the placed order', (WidgetTester tester) async {
    final SessionController session = SessionController();
    // Restores the session from the emulator-authenticated account.
    await session.bootstrap();
    expect(session.student, isNotNull);

    await tester.pumpWidget(
      ChangeNotifierProvider<SessionController>.value(
        value: session,
        child: MaterialApp(
          theme: AppTheme.light,
          home: const MyOrdersScreen(),
          routes: <String, WidgetBuilder>{
            '/customize': (_) => const SizedBox.shrink(),
            '/order-details': (_) => const SizedBox.shrink(),
            '/student-login': (_) => const SizedBox.shrink(),
          },
        ),
      ),
    );

    await pumpUntilFound(tester, find.text('Order #${placedOrderIds.first}'));
  });

  test('each order gets its own id — no shared CK1024, no overwrite', () async {
    final StudentProfile student = registered!;
    final OrderService orders = OrderService();

    final String secondId = await orders.generateOrderId();
    placedOrderIds.add(secondId);

    expect(secondId, isNot(placedOrderIds.first));
    expect(secondId, startsWith('CK2'));

    await orders.createOrder(buildOrder(orderId: secondId, student: student));

    // The first order is still there: the second id did not overwrite it.
    final List<Order> all = await orders
        .watchStudentOrders(student.studentId)
        .firstWhere(
          (List<Order> list) =>
              placedOrderIds.every(
                (String id) => list.any((Order order) => order.orderId == id),
              ),
        )
        .timeout(const Duration(seconds: 30));

    expect(all.map((Order order) => order.orderId), containsAll(placedOrderIds));
    expect(all.where((Order o) => o.orderId == 'CK1024'), isEmpty);
  });

  test('the ruleset in this repository allows the public app_meta read '
      'and refuses an anonymous order write', () async {
    final StudentProfile student = registered!;

    // Tidy up while we are still allowed to (this also exercises the delete
    // rules), then prove what an anonymous client can and cannot do.
    for (final String orderId in placedOrderIds) {
      await FirebaseFirestore.instance.collection('orders').doc(orderId).delete();
    }
    await FirebaseFirestore.instance.collection('students').doc(student.uid).delete();

    await FirebaseAuth.instance.signOut();
    expect(FirebaseAuth.instance.currentUser, isNull);

    // `app_meta` is public by design: the bootstrap flag has to be readable
    // before anyone signs in. A read that returns without throwing proves the
    // rule is live in the ruleset being enforced.
    await FirebaseFirestore.instance.collection('app_meta').doc('demo_seed').get();

    await expectLater(
      OrderService().createOrder(
        buildOrder(orderId: 'CK-DENIED-$runId', student: student),
      ),
      throwsA(
        isA<FirebaseException>()
            .having((FirebaseException e) => e.code, 'code', 'permission-denied'),
      ),
    );
  });
}
