// `hide Order` — cloud_firestore exports its own `Order` (an index enum) which
// would clash with the application's order model.
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../models/order.dart';
import 'firestore_paths.dart';

/// Order-number bookkeeping.
///
/// The number is issued from a single counter document (`app_meta/order_counter`)
/// inside a transaction, so:
///
///  * generating an id reads **one document**, never the `orders` collection;
///  * two simultaneous orders can never be handed the same number — Firestore
///    serialises the read-modify-write, and the losing transaction retries;
///  * no security rule has to grant students a collection-wide read.
///
/// The counter starts at [reserveFloor], so the first issued id is `CK2000`.
/// That is deliberately above the demo records (`CK1001`–`CK1005`) **and** above
/// `CK1024`, which the previous implementation returned for every order when
/// its collection read failed — issuing it again could overwrite a real order.
class OrderNumbering {
  OrderNumbering._();

  /// Highest number the demo seed uses (`CK1005`) plus headroom.
  static const int reserveFloor = 1999;

  /// `CK` + the number, e.g. `CK2000`.
  static const String prefix = 'CK';

  /// The next number to issue. [stored] is the counter document's value, if any.
  /// A missing, malformed or suspiciously low value can never move the counter
  /// backwards.
  static int nextNumber(int? stored) {
    if (stored == null || stored < reserveFloor) return reserveFloor + 1;
    return stored + 1;
  }

  static String format(int number) => '$prefix$number';

  /// `CK1001` -> `1001`. Returns `null` for anything unexpected.
  static int? parse(String orderId) {
    if (!orderId.startsWith(prefix)) return null;
    return int.tryParse(orderId.substring(prefix.length));
  }
}

/// Whether the current session is allowed to write an order.
///
/// Firestore rules check the **Firebase Authentication** credential, not the
/// in-memory profile. A restored profile whose Auth session is gone (expired
/// token, signed out elsewhere, a seed that signed out) therefore still looks
/// signed in to the UI while every write is rejected with
/// `cloud_firestore/permission-denied`. Checking both here is what turns that
/// into an explanation instead of a mystery.
class OrderPlacementGuard {
  OrderPlacementGuard._();

  /// `null` when an order may be written, otherwise a student-facing reason.
  static String? blockReason({
    required String? studentUid,
    required String? authUid,
  }) {
    if (studentUid == null || studentUid.isEmpty) {
      return 'Please sign in before placing an order.';
    }
    if (authUid == null || authUid.isEmpty) {
      return 'Your sign-in has expired. Please sign in again to place your order.';
    }
    if (authUid != studentUid) {
      return 'This profile does not belong to the signed-in account. '
          'Please sign in again.';
    }
    return null;
  }
}

/// Orders — the Firestore replacement for the order helpers in
/// `college-bakery/js/app.js` (`createOrder`, `getOrders`, `getStudentOrders`,
/// `getOrderById`, `updateOrderStatus`, `generateOrderId`) plus the
/// "Clear Demo Data" wipe.
class OrderService {
  OrderService({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _orders =>
      _firestore.collection(FirestorePaths.orders);

  /// `getOrders()` — every order, newest first (the dashboards sort the same
  /// way in `js/owner.js` and `js/orders.js`).
  Stream<List<Order>> watchAllOrders() => _orders
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snapshot) => _sortByCreatedAt(
            snapshot.docs.map(_fromDoc).toList(),
          ));

  /// `getStudentOrders(studentId)`
  Stream<List<Order>> watchStudentOrders(String studentId) => _orders
      .where('studentId', isEqualTo: studentId)
      .snapshots()
      .map((QuerySnapshot<Map<String, dynamic>> snapshot) => _sortByCreatedAt(
            snapshot.docs.map(_fromDoc).toList(),
          ));

  /// `getOrderById(orderId)`
  Stream<Order?> watchOrder(String orderId) =>
      _orders.doc(orderId).snapshots().map(
            (DocumentSnapshot<Map<String, dynamic>> snapshot) =>
                snapshot.exists && snapshot.data() != null
                    ? Order.fromMap(snapshot.data()!)
                    : null,
          );

  Future<Order?> fetchOrder(String orderId) async {
    final DocumentSnapshot<Map<String, dynamic>> snapshot =
        await _orders.doc(orderId).get();
    final Map<String, dynamic>? data = snapshot.data();
    return data == null ? null : Order.fromMap(data);
  }

  Future<List<Order>> fetchAllOrders() async {
    final QuerySnapshot<Map<String, dynamic>> snapshot = await _orders.get();
    return _sortByCreatedAt(snapshot.docs.map(_fromDoc).toList());
  }

  /// Issues the next order id from the `app_meta/order_counter` document.
  ///
  /// This used to read the entire `orders` collection and, on any read failure,
  /// silently return `CK1024`. That made a permissions problem look like a
  /// successful id (every order then overwrote the previous `CK1024`) and it
  /// required students to hold a collection-wide read on `orders`, which no
  /// sane rule set grants. Failures now propagate to the caller so the screen
  /// can say what actually went wrong.
  Future<String> generateOrderId() async {
    final DocumentReference<Map<String, dynamic>> counter = _firestore
        .collection(FirestorePaths.appMeta)
        .doc(FirestorePaths.orderCounter);

    final int number = await _firestore.runTransaction<int>(
      (Transaction transaction) async {
        final DocumentSnapshot<Map<String, dynamic>> snapshot =
            await transaction.get(counter);
        final Object? stored = snapshot.data()?['lastOrderNumber'];
        final int next = OrderNumbering.nextNumber(
          stored is int ? stored : (stored is num ? stored.toInt() : null),
        );
        transaction.set(
          counter,
          <String, dynamic>{
            'lastOrderNumber': next,
            'updatedAt': DateTime.now().toUtc().toIso8601String(),
          },
          SetOptions(merge: true),
        );
        return next;
      },
    );

    return OrderNumbering.format(number);
  }

  /// `createOrder(order)` — the document id is the order id, so
  /// `getOrderById()` is a direct document read.
  ///
  /// `set` (rather than an update) is deliberate: a retry after a failed
  /// submission reuses the id reserved for *that* submission (see
  /// `_pendingOrderId` in `CustomizeScreen`), so writing the same document
  /// again is the idempotent outcome we want — it can never duplicate an order
  /// or overwrite someone else's, because no other submission is ever given
  /// that id.
  Future<void> createOrder(Order order) =>
      _orders.doc(order.orderId).set(order.toMap());

  /// `updateOrderStatus()` — sets the status and refreshes `updatedAt`.
  Future<void> updateOrderStatus(String orderId, String newStatus) =>
      _orders.doc(orderId).update(<String, dynamic>{
        'status': newStatus,
        'updatedAt': DateTime.now().toUtc().toIso8601String(),
      });

  /// "Clear Demo Data" — removes every order.
  Future<void> deleteAllOrders() => _deleteCollection(_orders);

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

  Order _fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Order.fromMap(<String, dynamic>{
        ...doc.data() ?? <String, dynamic>{},
        'orderId': (doc.data()?['orderId'] ?? doc.id) as String,
      });

  List<Order> _sortByCreatedAt(List<Order> orders) {
    final List<Order> sorted = List<Order>.from(orders);
    sorted.sort((Order a, Order b) =>
        _millis(b.createdAt).compareTo(_millis(a.createdAt)));
    return sorted;
  }

  int _millis(String iso) => DateTime.tryParse(iso)?.millisecondsSinceEpoch ?? 0;
}
