// `hide Order` — cloud_firestore exports its own `Order` (an index enum) which
// would clash with the application's order model.
import 'package:cloud_firestore/cloud_firestore.dart' hide Order;

import '../models/order.dart';
import 'firestore_paths.dart';

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

  /// `generateOrderId()` — `CK1024`, `CK1025`, … starting from 1023.
  Future<String> generateOrderId() async {
    int maxNumber = 1023;
    try {
      final QuerySnapshot<Map<String, dynamic>> snapshot = await _orders.get();
      for (final QueryDocumentSnapshot<Map<String, dynamic>> doc in
          snapshot.docs) {
        final int? parsed =
            int.tryParse(doc.data()['orderId'].toString().replaceAll('CK', ''));
        if (parsed != null && parsed > maxNumber) maxNumber = parsed;
      }
    } on FirebaseException {
      // Fall back to the default counter if the collection cannot be read.
    }
    return 'CK${maxNumber + 1}';
  }

  /// `createOrder(order)` — the document id is the order id, so
  /// `getOrderById()` is a direct document read.
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
