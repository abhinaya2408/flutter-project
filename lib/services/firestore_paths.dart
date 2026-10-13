/// Firestore paths.
///
/// `js/app.js` keeps everything in six LocalStorage keys; the Flutter app maps
/// them onto these Firestore locations:
///
/// ```text
/// bakery_students        -> students/{uid}
/// bakery_owner_session   -> bakery_members/{uid}
/// bakery_orders          -> orders/{orderId}
/// bakery_notifications   -> notifications/{notificationId}
/// bakery_seeded          -> app_meta/demo_seed
/// bakery_current_user    -> Firebase Authentication session
/// ```
class FirestorePaths {
  FirestorePaths._();

  static const String students = 'students';
  static const String bakeryMembers = 'bakery_members';
  static const String orders = 'orders';
  static const String notifications = 'notifications';

  /// Bootstrap metadata (the LocalStorage `bakery_seeded` flag). Kept outside
  /// the user collections because it must be readable before anyone signs in.
  static const String appMeta = 'app_meta';
  static const String demoSeed = 'demo_seed';

  /// The uids of the seeded demo accounts. Firebase Authentication accounts
  /// cannot be re-listed from the client, so their uids are remembered here so
  /// "Clear Demo Data" can re-seed without signing anybody in.
  static const String demoAccounts = 'demo_accounts';

  /// `app_meta/order_counter` — the order-number counter. Kept in `app_meta`
  /// because that collection is already readable/writable by signed-in users
  /// under both the current rules and `firestore.rules.proposed`, so issuing an
  /// order id needs no rule change.
  static const String orderCounter = 'order_counter';
}
