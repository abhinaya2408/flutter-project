import 'package:college_bakery_flutter/data/order_status.dart';
import 'package:college_bakery_flutter/models/order.dart';
import 'package:college_bakery_flutter/services/order_service.dart';
import 'package:flutter_test/flutter_test.dart';

Order buildOrder({String orderId = 'CK2000'}) => Order(
      orderId: orderId,
      studentId: 'STU2024001',
      studentName: 'Ananya Sharma',
      studentEmail: 'ananya.sharma@yourcollege.edu',
      studentPhone: '9876543210',
      flavor: 'Chocolate',
      cakeType: 'Eggless',
      size: '1 Kg',
      cream: 'Chocolate',
      decorations: const <String>['Sprinkles'],
      cakeMessage: 'Happy Birthday!',
      specialInstructions: 'Pack securely',
      referenceImage: 'https://res.cloudinary.com/haryqfbk/image/upload/v1/cake.png',
      requiredDate: '2026-11-01',
      requiredTime: '16:00',
      estimatedPrice: 900,
      status: OrderStatus.pending,
      createdAt: '2026-10-13T10:00:00.000Z',
      updatedAt: '2026-10-13T10:00:00.000Z',
    );

void main() {
  group('OrderNumbering.nextNumber', () {
    test('starts above the demo range and the old broken fallback', () {
      final int first = OrderNumbering.nextNumber(null);
      expect(first, 2000);
      expect(OrderNumbering.format(first), 'CK2000');
    });

    test('never returns the id the old fallback produced for every order', () {
      // `CK1024` was returned whenever the old whole-collection read failed, so
      // every order overwrote the previous one. It must never be issued again.
      expect(OrderNumbering.format(OrderNumbering.nextNumber(null)), isNot('CK1024'));
      expect(OrderNumbering.nextNumber(1023), 2000);
    });

    test('cannot be pushed backwards by a missing or tampered value', () {
      expect(OrderNumbering.nextNumber(0), 2000);
      expect(OrderNumbering.nextNumber(500), 2000);
      expect(OrderNumbering.nextNumber(-9999), 2000);
      expect(OrderNumbering.nextNumber(1999), 2000);
    });

    test('increments normally from a stored counter', () {
      expect(OrderNumbering.nextNumber(2000), 2001);
      expect(OrderNumbering.nextNumber(2001), 2002);
      expect(OrderNumbering.nextNumber(99999), 100000);
    });
  });

  group('OrderNumbering.parse', () {
    test('reads the existing order ids back', () {
      expect(OrderNumbering.parse('CK1001'), 1001);
      expect(OrderNumbering.parse('CK2000'), 2000);
    });

    test('rejects anything unexpected', () {
      expect(OrderNumbering.parse(''), isNull);
      expect(OrderNumbering.parse('CK'), isNull);
      expect(OrderNumbering.parse('CKabc'), isNull);
      expect(OrderNumbering.parse('ORDER-1'), isNull);
      expect(OrderNumbering.parse('1001'), isNull);
    });
  });

  group('issuing numbers sequentially', () {
    test('produces 200 unique ids, all clear of the demo records', () {
      int? counter;
      final Set<String> ids = <String>{};

      for (int i = 0; i < 200; i += 1) {
        counter = OrderNumbering.nextNumber(counter);
        ids.add(OrderNumbering.format(counter));
      }

      expect(ids, hasLength(200));
      for (final String id in ids) {
        // Every id is above the seeded CK1001–CK1005 records.
        expect(OrderNumbering.parse(id)!, greaterThan(1005));
      }
    });
  });

  group('the order model is unchanged', () {
    test('toMap keeps every field the rules and screens rely on', () {
      final Map<String, dynamic> map = buildOrder().toMap();

      expect(
        map.keys.toSet(),
        <String>{
          'orderId',
          'studentId',
          'studentName',
          'studentEmail',
          'studentPhone',
          'flavor',
          'cakeType',
          'size',
          'cream',
          'decorations',
          'cakeMessage',
          'specialInstructions',
          'referenceImage',
          'requiredDate',
          'requiredTime',
          'estimatedPrice',
          'status',
          'createdAt',
          'updatedAt',
        },
      );
      expect(map['status'], OrderStatus.pending);
      expect(map['estimatedPrice'], 900);
      expect(map['studentId'], 'STU2024001');
    });

    test('fromMap round-trips an order', () {
      final Order original = buildOrder(orderId: 'CK2042');
      final Order restored = Order.fromMap(original.toMap());

      expect(restored.orderId, 'CK2042');
      expect(restored.studentId, original.studentId);
      expect(restored.referenceImage, original.referenceImage);
      expect(restored.decorations, original.decorations);
      expect(restored.estimatedPrice, original.estimatedPrice);
      expect(restored.status, original.status);
      expect(restored.createdAt, original.createdAt);
    });
  });
}
