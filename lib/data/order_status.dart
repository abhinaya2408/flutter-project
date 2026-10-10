import '../theme/app_colors.dart';
import 'package:flutter/widgets.dart';

/// Order status vocabulary — a direct port of the status constants in
/// `college-bakery/js/app.js`, `js/orders.js` and `js/owner.js`.
///
/// The statuses themselves are never renamed: `PENDING → ACCEPTED → PREPARING
/// → READY → COMPLETED`, with `REJECTED` available from `PENDING`.
class OrderStatus {
  OrderStatus._();

  static const String pending = 'PENDING';
  static const String accepted = 'ACCEPTED';
  static const String preparing = 'PREPARING';
  static const String ready = 'READY';
  static const String completed = 'COMPLETED';
  static const String rejected = 'REJECTED';

  /// `STATUS_STEPS` — the tracker progression.
  static const List<String> steps = <String>[
    'PENDING',
    'ACCEPTED',
    'PREPARING',
    'READY',
    'COMPLETED',
  ];

  /// The five tracker labels rendered by `renderTracker()` in `js/orders.js`.
  static const List<String> trackerLabels = <String>[
    'Order Placed',
    'Accepted',
    'Preparing',
    'Ready',
    'Collected',
  ];

  /// `STATUS_MESSAGES` — the notification text created when the bakery moves an
  /// order. `{id}` is the order id, e.g. `CK1001`.
  static String notificationMessage(String status, String orderId) {
    switch (status) {
      case accepted:
        return 'Your cake order #$orderId has been accepted.';
      case preparing:
        return 'Your cake order #$orderId is now being prepared.';
      case ready:
        return 'Your cake order #$orderId is ready for collection! 🎂';
      case completed:
        return 'Your cake order #$orderId has been collected. Thank you!';
      case rejected:
        return "We're sorry, your cake order #$orderId could not be accepted.";
      default:
        return '';
    }
  }

  /// `STATUS_TOASTS` — the confirmation toast shown to the bakery member.
  static String actionToast(String status) {
    switch (status) {
      case accepted:
        return 'Order accepted.';
      case rejected:
        return 'Order rejected.';
      case preparing:
        return 'Cake is now being prepared.';
      case ready:
        return 'Cake marked as ready.';
      case completed:
        return 'Order marked as collected.';
      default:
        return 'Order updated.';
    }
  }

  /// `My Orders` tab buckets (`matchesTab()` in `js/orders.js`).
  static bool matchesTab(String status, String tab) {
    switch (tab) {
      case 'all':
        return true;
      case 'active':
        return <String>[pending, accepted, preparing].contains(status);
      case 'ready':
        return status == ready;
      case 'completed':
        return <String>[completed, 'COLLECTED'].contains(status);
      default:
        return true;
    }
  }

  /// `.pill-*` colours from `style.css`.
  static Color pillBackground(String status) {
    switch (status) {
      case pending:
      case preparing:
        return AppColors.pillPendingBackground;
      case accepted:
        return AppColors.pillAcceptedBackground;
      case ready:
        return AppColors.pillReadyBackground;
      case 'COLLECTED':
      case completed:
        return AppColors.border;
      case rejected:
        return AppColors.pillRejectedBackground;
      default:
        return AppColors.border;
    }
  }

  /// `.pill-*` foreground colours from `style.css`.
  static Color pillForeground(String status) {
    switch (status) {
      case pending:
      case preparing:
        return AppColors.warning;
      case accepted:
        return AppColors.pillAcceptedText;
      case ready:
        return AppColors.success;
      case 'COLLECTED':
      case completed:
        return AppColors.textMuted;
      case rejected:
        return AppColors.danger;
      default:
        return AppColors.textMuted;
    }
  }

  /// Dashboard status filters (`#filterPills` in `owner-dashboard.html`).
  static const List<Map<String, String>> dashboardFilters = <Map<String, String>>[
    <String, String>{'value': 'all', 'label': 'All'},
    <String, String>{'value': pending, 'label': 'Pending'},
    <String, String>{'value': accepted, 'label': 'Accepted'},
    <String, String>{'value': preparing, 'label': 'Preparing'},
    <String, String>{'value': ready, 'label': 'Ready'},
    <String, String>{'value': completed, 'label': 'Completed'},
    <String, String>{'value': rejected, 'label': 'Rejected'},
  ];
}
