import 'package:college_bakery_flutter/data/order_status.dart';
import 'package:college_bakery_flutter/models/order.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('status vocabulary', () {
    test('progression is unchanged', () {
      expect(OrderStatus.steps,
          <String>['PENDING', 'ACCEPTED', 'PREPARING', 'READY', 'COMPLETED']);
      expect(OrderStatus.trackerLabels, <String>[
        'Order Placed',
        'Accepted',
        'Preparing',
        'Ready',
        'Collected',
      ]);
    });

    test('dashboard filters', () {
      expect(
        OrderStatus.dashboardFilters.map((Map<String, String> filter) =>
            filter['label']).toList(),
        <String>[
          'All',
          'Pending',
          'Accepted',
          'Preparing',
          'Ready',
          'Completed',
          'Rejected',
        ],
      );
    });
  });

  group('My Orders tabs', () {
    test('all', () {
      expect(OrderStatus.matchesTab('PENDING', 'all'), isTrue);
      expect(OrderStatus.matchesTab('REJECTED', 'all'), isTrue);
    });

    test('active', () {
      expect(OrderStatus.matchesTab('PENDING', 'active'), isTrue);
      expect(OrderStatus.matchesTab('ACCEPTED', 'active'), isTrue);
      expect(OrderStatus.matchesTab('PREPARING', 'active'), isTrue);
      expect(OrderStatus.matchesTab('READY', 'active'), isFalse);
    });

    test('ready', () {
      expect(OrderStatus.matchesTab('READY', 'ready'), isTrue);
      expect(OrderStatus.matchesTab('PREPARING', 'ready'), isFalse);
    });

    test('completed includes COLLECTED', () {
      expect(OrderStatus.matchesTab('COMPLETED', 'completed'), isTrue);
      expect(OrderStatus.matchesTab('COLLECTED', 'completed'), isTrue);
      expect(OrderStatus.matchesTab('READY', 'completed'), isFalse);
    });
  });

  group('notifications (STATUS_MESSAGES)', () {
    test('exact texts', () {
      expect(
        OrderStatus.notificationMessage('ACCEPTED', 'CK1001'),
        'Your cake order #CK1001 has been accepted.',
      );
      expect(
        OrderStatus.notificationMessage('PREPARING', 'CK1001'),
        'Your cake order #CK1001 is now being prepared.',
      );
      expect(
        OrderStatus.notificationMessage('READY', 'CK1001'),
        'Your cake order #CK1001 is ready for collection! 🎂',
      );
      expect(
        OrderStatus.notificationMessage('COMPLETED', 'CK1001'),
        'Your cake order #CK1001 has been collected. Thank you!',
      );
      expect(
        OrderStatus.notificationMessage('REJECTED', 'CK1001'),
        "We're sorry, your cake order #CK1001 could not be accepted.",
      );
      expect(OrderStatus.notificationMessage('PENDING', 'CK1001'), '');
    });

    test('owner action toasts', () {
      expect(OrderStatus.actionToast('ACCEPTED'), 'Order accepted.');
      expect(OrderStatus.actionToast('REJECTED'), 'Order rejected.');
      expect(
        OrderStatus.actionToast('PREPARING'),
        'Cake is now being prepared.',
      );
      expect(OrderStatus.actionToast('READY'), 'Cake marked as ready.');
      expect(
        OrderStatus.actionToast('COMPLETED'),
        'Order marked as collected.',
      );
    });
  });

  group('owner actions (renderOwnerActions)', () {
    test('PENDING offers accept and reject', () {
      final List<Map<String, String>> actions =
          Order.actionsByStatus['PENDING']!;
      expect(actions.length, 2);
      expect(actions[0]['label'], 'Accept Order');
      expect(actions[0]['status'], 'ACCEPTED');
      expect(actions[1]['label'], 'Reject Order');
      expect(actions[1]['status'], 'REJECTED');
      expect(actions[1]['variant'], 'danger');
    });

    test('each later status advances one step', () {
      expect(Order.actionsByStatus['ACCEPTED']!.single['label'],
          'Start Preparing');
      expect(Order.actionsByStatus['PREPARING']!.single['label'],
          'Mark Cake Ready');
      expect(Order.actionsByStatus['READY']!.single['label'], 'Mark Collected');
    });

    test('completed, collected and rejected have no actions', () {
      expect(Order.actionsByStatus['COMPLETED'], isNull);
      expect(Order.actionsByStatus['COLLECTED'], isNull);
      expect(Order.actionsByStatus['REJECTED'], isNull);
    });
  });
}
