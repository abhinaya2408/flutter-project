// `hide Order` — cloud_firestore exports its own `Order` (an index enum) which
// would clash with the application's order model.
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../data/order_status.dart';
import '../models/app_notification.dart';
import '../models/order.dart';
import '../models/student_profile.dart';
import '../utils/formatters.dart';
import '../utils/pricing.dart';
import 'firestore_paths.dart';
import 'reference_image_service.dart';

/// Demo data — the Firebase port of `seedDemoData()` and `clearDemoData()` in
/// `college-bakery/js/app.js`.
///
/// The same three students, the same five orders (`CK1001`–`CK1005`) and the
/// same five notifications are written. The only difference is that the demo
/// passwords live in Firebase Authentication instead of a plaintext field, so
/// the seeder creates the demo accounts through the Auth API.
class DemoSeedService {
  DemoSeedService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    ReferenceImageService? referenceImages,
  })  : _auth = auth ?? FirebaseAuth.instance,
        _firestore = firestore ?? FirebaseFirestore.instance,
        _referenceImages = referenceImages ?? ReferenceImageService();

  static const String _demoSeedFlag = FirestorePaths.demoSeed;

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final ReferenceImageService _referenceImages;

  CollectionReference<Map<String, dynamic>> get _appMeta =>
      _firestore.collection(FirestorePaths.appMeta);

  CollectionReference<Map<String, dynamic>> get _students =>
      _firestore.collection(FirestorePaths.students);

  CollectionReference<Map<String, dynamic>> get _members =>
      _firestore.collection(FirestorePaths.bakeryMembers);

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection(FirestorePaths.orders);

  CollectionReference<Map<String, dynamic>> get _notifications =>
      _firestore.collection(FirestorePaths.notifications);

  /// The `bakery_seeded` guard: seeds once, on first launch.
  Future<void> ensureSeeded() async {
    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot =
          await _appMeta.doc(_demoSeedFlag).get();
      if (snapshot.data() != null && snapshot.data()!['seeded'] == true) {
        return;
      }
    } on FirebaseException catch (error) {
      debugPrint('DemoSeedService: could not read the seed flag (${error.code}).');
    }

    try {
      await _seed(ensureAccounts: true);
    } on FirebaseAuthException catch (error) {
      debugPrint('DemoSeedService: seeding failed (${error.code}).');
    } on FirebaseException catch (error) {
      debugPrint(
        'DemoSeedService: seeding failed (${error.code}: ${error.message}).',
      );
    }
  }

  /// The "Clear Demo Data" action: wipe, then re-seed exactly like the
  /// original link in the bakery dashboard sidebar.
  Future<void> clearAndReseed() async {
    await _wipe();
    await _seed(ensureAccounts: false);
  }

  // ---------- Wipe ----------
  Future<void> _wipe() async {
    await _deleteCollection(_orders);
    await _deleteCollection(_notifications);

    final DocumentSnapshot<Map<String, dynamic>> accounts =
        await _appMeta.doc(FirestorePaths.demoAccounts).get();
    final List<dynamic> demoStudents =
        (accounts.data()?['students'] as List<dynamic>?) ?? <dynamic>[];
    for (final dynamic entry in demoStudents) {
      final String uid = (entry as Map<String, dynamic>)['uid'] as String? ?? '';
      if (uid.isEmpty) continue;
      await _students.doc(uid).delete();
    }

    await _referenceImages.deleteAllReferenceImages();
    await _appMeta.doc(_demoSeedFlag).delete();
  }

  // ---------- Seed ----------
  /// The original `seedDemoData()` runs before anybody signs in, so the app is
  /// always left signed out afterwards — including when the seed failed
  /// part-way through (a denied write used to leave a demo account signed in,
  /// which then made every later sign-in look broken).
  Future<void> _seed({required bool ensureAccounts}) async {
    final bool hadSession = _auth.currentUser != null;
    try {
      await _seedRecords(ensureAccounts: ensureAccounts);
    } finally {
      if (ensureAccounts && !hadSession) {
        await _auth.signOut();
      }
    }
  }

  Future<void> _seedRecords({required bool ensureAccounts}) async {
    final List<Map<String, String>> accounts = <Map<String, String>>[];

    if (ensureAccounts) {
      for (final DemoAccount account in AppConfig.demoStudents) {
        final String uid = await _signInOrCreate(
          account.email,
          AppConfig.demoStudentPassword,
        );
        accounts.add(<String, String>{
          'uid': uid,
          'studentId': account.studentId,
          'fullName': account.fullName,
          'email': account.email,
          'phone': account.phone,
        });
        await _students.doc(uid).set(
              StudentProfile(
                uid: uid,
                studentId: account.studentId,
                fullName: account.fullName,
                email: account.email,
                phone: account.phone,
              ).toMap(),
            );
      }

      final String ownerUid = await _signInOrCreate(
        AppConfig.demoOwnerEmail,
        AppConfig.demoOwnerPassword,
      );
      await _members.doc(ownerUid).set(<String, dynamic>{
        'email': AppConfig.demoOwnerEmail,
        'role': 'owner',
      });

      await _appMeta.doc(FirestorePaths.demoAccounts).set(<String, dynamic>{
        'ownerUid': ownerUid,
        'students': accounts,
      });
    } else {
      final DocumentSnapshot<Map<String, dynamic>> stored =
          await _appMeta.doc(FirestorePaths.demoAccounts).get();
      final List<dynamic> demoStudents =
          (stored.data()?['students'] as List<dynamic>?) ?? <dynamic>[];
      if (demoStudents.isEmpty) {
        // The uids were never recorded (fresh install) — fall back to creating
        // the accounts again; Firebase Authentication keeps them idempotent.
        return _seedRecords(ensureAccounts: true);
      }
      for (final dynamic entry in demoStudents) {
        final Map<String, dynamic> record = entry as Map<String, dynamic>;
        accounts.add(<String, String>{
          'uid': record['uid'] as String,
          'studentId': record['studentId'] as String,
          'fullName': record['fullName'] as String,
          'email': record['email'] as String,
          'phone': record['phone'] as String,
        });
        await _students.doc(record['uid'] as String).set(
              StudentProfile(
                uid: record['uid'] as String,
                studentId: record['studentId'] as String,
                fullName: record['fullName'] as String,
                email: record['email'] as String,
                phone: record['phone'] as String,
              ).toMap(),
            );
      }
    }

    for (final Order order in _demoOrders()) {
      await _orders.doc(order.orderId).set(order.toMap());
    }
    for (final AppNotification notification in _demoNotifications()) {
      await _notifications.doc(notification.id).set(notification.toMap());
    }

    await _appMeta.doc(_demoSeedFlag).set(<String, dynamic>{
      'seeded': true,
      'seededAt': DateTime.now().toUtc().toIso8601String(),
    });
  }

  /// Sign in when the account exists, create it otherwise.
  Future<String> _signInOrCreate(String email, String password) async {
    try {
      final UserCredential credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user!.uid;
    } on FirebaseAuthException catch (error) {
      const Set<String> missingAccountCodes = <String>{
        'user-not-found',
        'wrong-password',
        'invalid-credential',
        'invalid-login-credentials',
      };
      if (!missingAccountCodes.contains(error.code)) rethrow;
      final UserCredential credential =
          await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return credential.user!.uid;
    }
  }

  // ---------- The seeded records (verbatim from `seedDemoData()`) ----------
  List<Order> _demoOrders() {
    final DateTime now = DateTime.now();

    String plusDays(int days) =>
        Formatters.dateOnly(now.add(Duration(days: days)));

    String ago(int milliseconds) => DateTime.fromMillisecondsSinceEpoch(
          now.millisecondsSinceEpoch - milliseconds,
          isUtc: true,
        ).toIso8601String();

    List<String> decorationsOf(String a, [String? b]) =>
        <String>[a, ?b];

    return <Order>[
      Order(
        orderId: 'CK1001',
        studentId: 'STU2024001',
        studentName: 'Ananya Sharma',
        studentEmail: 'ananya.sharma@yourcollege.edu',
        studentPhone: '9876543210',
        flavor: 'Chocolate',
        cakeType: 'Eggless',
        size: '1 Kg',
        cream: 'Chocolate',
        decorations: decorationsOf('Sprinkles', 'Birthday Theme'),
        cakeMessage: 'Happy Birthday Rhea!',
        specialInstructions:
            'Please pack it securely, will be carried on a bike.',
        referenceImage: '',
        requiredDate: plusDays(2),
        requiredTime: '16:00',
        estimatedPrice: calculatePrice(
          flavor: 'Chocolate',
          size: '1 Kg',
          decorations: decorationsOf('Sprinkles', 'Birthday Theme'),
        ).total,
        status: OrderStatus.preparing,
        createdAt: ago(86400000),
        updatedAt: ago(3600000),
      ),
      Order(
        orderId: 'CK1002',
        studentId: 'STU2024002',
        studentName: 'Priya Verma',
        studentEmail: 'priya.verma@yourcollege.edu',
        studentPhone: '9876543211',
        flavor: 'Red Velvet',
        cakeType: 'Egg',
        size: '1.5 Kg',
        cream: 'Vanilla',
        decorations: decorationsOf('Fresh Flowers'),
        cakeMessage: 'Congrats Team!',
        specialInstructions: '',
        referenceImage: '',
        requiredDate: plusDays(1),
        requiredTime: '11:30',
        estimatedPrice: calculatePrice(
          flavor: 'Red Velvet',
          size: '1.5 Kg',
          decorations: decorationsOf('Fresh Flowers'),
        ).total,
        status: OrderStatus.ready,
        createdAt: ago(172800000),
        updatedAt: ago(7200000),
      ),
      Order(
        orderId: 'CK1003',
        studentId: 'STU2024003',
        studentName: 'Rahul Nair',
        studentEmail: 'rahul.nair@yourcollege.edu',
        studentPhone: '9876543212',
        flavor: 'Butterscotch',
        cakeType: 'Eggless',
        size: '500g',
        cream: 'Butterscotch',
        decorations: const <String>[],
        cakeMessage: '',
        specialInstructions: 'Small farewell cake for hostel room.',
        referenceImage: '',
        requiredDate: plusDays(4),
        requiredTime: '18:00',
        estimatedPrice: calculatePrice(
          flavor: 'Butterscotch',
          size: '500g',
        ).total,
        status: OrderStatus.pending,
        createdAt: ago(5400000),
        updatedAt: ago(5400000),
      ),
      Order(
        orderId: 'CK1004',
        studentId: 'STU2024001',
        studentName: 'Ananya Sharma',
        studentEmail: 'ananya.sharma@yourcollege.edu',
        studentPhone: '9876543210',
        flavor: 'Black Forest',
        cakeType: 'Egg',
        size: '2 Kg',
        cream: 'Chocolate',
        decorations: decorationsOf('Chocolate Decorations', 'Fruits'),
        cakeMessage: 'Happy Anniversary!',
        specialInstructions: '',
        referenceImage: '',
        requiredDate: plusDays(-3),
        requiredTime: '10:00',
        estimatedPrice: calculatePrice(
          flavor: 'Black Forest',
          size: '2 Kg',
          decorations: decorationsOf('Chocolate Decorations', 'Fruits'),
        ).total,
        status: OrderStatus.completed,
        createdAt: ago(604800000),
        updatedAt: ago(500000000),
      ),
      Order(
        orderId: 'CK1005',
        studentId: 'STU2024002',
        studentName: 'Priya Verma',
        studentEmail: 'priya.verma@yourcollege.edu',
        studentPhone: '9876543211',
        flavor: 'Strawberry',
        cakeType: 'Eggless',
        size: '1 Kg',
        cream: 'Strawberry',
        decorations: decorationsOf('Fresh Flowers', 'Sprinkles'),
        cakeMessage: 'Happy Birthday Priya!',
        specialInstructions: 'Please use pink and white decoration.',
        referenceImage: '',
        requiredDate: plusDays(3),
        requiredTime: '17:00',
        estimatedPrice: calculatePrice(
          flavor: 'Strawberry',
          size: '1 Kg',
          decorations: decorationsOf('Fresh Flowers', 'Sprinkles'),
        ).total,
        status: OrderStatus.accepted,
        createdAt: ago(90000000),
        updatedAt: ago(40000000),
      ),
    ];
  }

  List<AppNotification> _demoNotifications() {
    final DateTime now = DateTime.now();
    String ago(int milliseconds) => DateTime.fromMillisecondsSinceEpoch(
          now.millisecondsSinceEpoch - milliseconds,
          isUtc: true,
        ).toIso8601String();

    return <AppNotification>[
      AppNotification(
        id: 'N1',
        studentId: 'STU2024001',
        orderId: 'CK1001',
        message: 'Your cake order #CK1001 is now being prepared.',
        read: false,
        createdAt: ago(3600000),
      ),
      AppNotification(
        id: 'N2',
        studentId: 'STU2024001',
        orderId: 'CK1001',
        message: 'Your cake order #CK1001 has been accepted.',
        read: true,
        createdAt: ago(80000000),
      ),
      AppNotification(
        id: 'N3',
        studentId: 'STU2024002',
        orderId: 'CK1002',
        message: 'Your cake order #CK1002 is ready for collection! 🎂',
        read: false,
        createdAt: ago(7200000),
      ),
      AppNotification(
        id: 'N4',
        studentId: 'STU2024001',
        orderId: 'CK1004',
        message: 'Your cake order #CK1004 has been collected. Thank you!',
        read: true,
        createdAt: ago(500000000),
      ),
      AppNotification(
        id: 'N5',
        studentId: 'STU2024002',
        orderId: 'CK1005',
        message: 'Your cake order #CK1005 has been accepted.',
        read: false,
        createdAt: ago(40000000),
      ),
    ];
  }

  Future<void> _deleteCollection(
    CollectionReference<Map<String, dynamic>> collection,
  ) async {
    final QuerySnapshot<Map<String, dynamic>> snapshot =
        await collection.limit(400).get();
    if (snapshot.docs.isEmpty) return;
    final WriteBatch batch = _firestore.batch();
    for (final QueryDocumentSnapshot<Map<String, dynamic>> doc
        in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
    if (snapshot.docs.length == 400) {
      await _deleteCollection(collection);
    }
  }
}
