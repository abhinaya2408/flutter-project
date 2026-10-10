import 'package:college_bakery_flutter/models/app_notification.dart';
import 'package:college_bakery_flutter/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final Order order = Order(
    orderId: 'CK1001',
    studentId: 'STU2024001',
    studentName: 'Ananya Sharma',
    studentEmail: 'ananya.sharma@yourcollege.edu',
    studentPhone: '9876543210',
    flavor: 'Chocolate',
    cakeType: 'Eggless',
    size: '1 Kg',
    cream: 'Chocolate',
    decorations: <String>['Sprinkles', 'Birthday Theme'],
    cakeMessage: 'Happy Birthday Rhea!',
    specialInstructions: 'Please pack it securely, will be carried on a bike.',
    referenceImage: '',
    requiredDate: '2026-10-08',
    requiredTime: '16:00',
    estimatedPrice: 680,
    status: 'PREPARING',
    createdAt: '2026-10-05T10:00:00.000Z',
    updatedAt: '2026-10-06T09:00:00.000Z',
  );

  test('toMap keeps every field the original order object has', () {
    final Map<String, dynamic> map = order.toMap();
    expect(map.keys.toSet(), <String>{
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
    });
    expect(map['decorations'], <String>['Sprinkles', 'Birthday Theme']);
    expect(map['estimatedPrice'], 680);
  });

  test('fromMap round-trips', () {
    final Order restored = Order.fromMap(order.toMap());
    expect(restored.orderId, order.orderId);
    expect(restored.studentPhone, order.studentPhone);
    expect(restored.decorations, order.decorations);
    expect(restored.requiredTime, order.requiredTime);
    expect(restored.status, order.status);
  });

  test('fromMap tolerates missing and numeric fields', () {
    final Order parsed = Order.fromMap(<String, dynamic>{
      'orderId': 'CK1002',
      'estimatedPrice': 850.0,
      'decorations': <dynamic>['Fresh Flowers'],
    });
    expect(parsed.estimatedPrice, 850);
    expect(parsed.decorations, <String>['Fresh Flowers']);
    expect(parsed.cakeMessage, '');
  });

  test('copyWith replaces only the status and updatedAt', () {
    final Order updated = order.copyWith(
      status: 'READY',
      updatedAt: '2026-10-06T12:00:00.000Z',
    );
    expect(updated.status, 'READY');
    expect(updated.updatedAt, '2026-10-06T12:00:00.000Z');
    expect(updated.orderId, order.orderId);
    expect(updated.createdAt, order.createdAt);
  });

  test('notification document shape', () {
    const AppNotification notification = AppNotification(
      id: 'N1',
      studentId: 'STU2024001',
      orderId: 'CK1001',
      message: 'Your cake order #CK1001 is now being prepared.',
      read: false,
      createdAt: '2026-10-05T18:00:00.000Z',
    );
    expect(notification.toMap().keys.toSet(), <String>{
      'id',
      'studentId',
      'orderId',
      'message',
      'read',
      'createdAt',
    });
    expect(AppNotification.fromMap(notification.toMap()).read, isFalse);
    expect(notification.copyWith(read: true).read, isTrue);
  });

  test('notification ids follow the "N" + timestamp + random pattern', () {
    expect(AppNotification.generateId(), startsWith('N'));
  });
}
