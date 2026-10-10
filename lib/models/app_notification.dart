import 'dart:math' as math;

/// A notification — `createNotification()` in `college-bakery/js/app.js`.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.studentId,
    required this.orderId,
    required this.message,
    required this.read,
    required this.createdAt,
  });

  final String id;
  final String studentId;
  final String orderId;
  final String message;
  final bool read;

  /// ISO-8601 string, as stored by the web prototype.
  final String createdAt;

  AppNotification copyWith({bool? read}) => AppNotification(
        id: id,
        studentId: studentId,
        orderId: orderId,
        message: message,
        read: read ?? this.read,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'id': id,
        'studentId': studentId,
        'orderId': orderId,
        'message': message,
        'read': read,
        'createdAt': createdAt,
      };

  factory AppNotification.fromMap(Map<String, dynamic> map) => AppNotification(
        id: (map['id'] ?? '') as String,
        studentId: (map['studentId'] ?? '') as String,
        orderId: (map['orderId'] ?? '') as String,
        message: (map['message'] ?? '') as String,
        read: map['read'] == true,
        createdAt: (map['createdAt'] ?? '') as String,
      );

  /// `"N" + Date.now() + Math.floor(Math.random() * 1000)`
  static String generateId() =>
      'N${DateTime.now().millisecondsSinceEpoch}${math.Random().nextInt(1000)}';
}
