import '../data/order_status.dart';

/// An order — the same document shape `createOrder()` writes in
/// `college-bakery/js/customize.js` (keys, order and string formats preserved
/// so the Firestore data mirrors the original LocalStorage records).
class Order {
  const Order({
    required this.orderId,
    required this.studentId,
    required this.studentName,
    required this.studentEmail,
    required this.studentPhone,
    required this.flavor,
    required this.cakeType,
    required this.size,
    required this.cream,
    required this.decorations,
    required this.cakeMessage,
    required this.specialInstructions,
    required this.referenceImage,
    required this.requiredDate,
    required this.requiredTime,
    required this.estimatedPrice,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  final String orderId;
  final String studentId;
  final String studentName;
  final String studentEmail;
  final String studentPhone;
  final String flavor;
  final String cakeType;
  final String size;
  final String cream;
  final List<String> decorations;
  final String cakeMessage;
  final String specialInstructions;

  /// Firebase Storage download URL (empty when no reference photo was
  /// uploaded), replacing the original Data-URL string.
  final String referenceImage;

  /// `YYYY-MM-DD`
  final String requiredDate;

  /// `HH:mm`
  final String requiredTime;

  final int estimatedPrice;
  final String status;

  /// ISO-8601 strings, exactly like the web prototype.
  final String createdAt;
  final String updatedAt;

  /// Owner action for the current status, or `null` when the order is done.
  /// Mirrors `renderOwnerActions()` in `js/owner.js`.
  static const Map<String, List<Map<String, String>>> actionsByStatus =
      <String, List<Map<String, String>>>{
    OrderStatus.pending: <Map<String, String>>[
      <String, String>{'label': 'Accept Order', 'status': OrderStatus.accepted, 'variant': 'primary'},
      <String, String>{'label': 'Reject Order', 'status': OrderStatus.rejected, 'variant': 'danger'},
    ],
    OrderStatus.accepted: <Map<String, String>>[
      <String, String>{'label': 'Start Preparing', 'status': OrderStatus.preparing, 'variant': 'primary'},
    ],
    OrderStatus.preparing: <Map<String, String>>[
      <String, String>{'label': 'Mark Cake Ready', 'status': OrderStatus.ready, 'variant': 'primary'},
    ],
    OrderStatus.ready: <Map<String, String>>[
      <String, String>{'label': 'Mark Collected', 'status': OrderStatus.completed, 'variant': 'primary'},
    ],
  };

  Order copyWith({String? status, String? updatedAt}) => Order(
        orderId: orderId,
        studentId: studentId,
        studentName: studentName,
        studentEmail: studentEmail,
        studentPhone: studentPhone,
        flavor: flavor,
        cakeType: cakeType,
        size: size,
        cream: cream,
        decorations: decorations,
        cakeMessage: cakeMessage,
        specialInstructions: specialInstructions,
        referenceImage: referenceImage,
        requiredDate: requiredDate,
        requiredTime: requiredTime,
        estimatedPrice: estimatedPrice,
        status: status ?? this.status,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  Map<String, dynamic> toMap() => <String, dynamic>{
        'orderId': orderId,
        'studentId': studentId,
        'studentName': studentName,
        'studentEmail': studentEmail,
        'studentPhone': studentPhone,
        'flavor': flavor,
        'cakeType': cakeType,
        'size': size,
        'cream': cream,
        'decorations': decorations,
        'cakeMessage': cakeMessage,
        'specialInstructions': specialInstructions,
        'referenceImage': referenceImage,
        'requiredDate': requiredDate,
        'requiredTime': requiredTime,
        'estimatedPrice': estimatedPrice,
        'status': status,
        'createdAt': createdAt,
        'updatedAt': updatedAt,
      };

  factory Order.fromMap(Map<String, dynamic> map) => Order(
        orderId: (map['orderId'] ?? '') as String,
        studentId: (map['studentId'] ?? '') as String,
        studentName: (map['studentName'] ?? '') as String,
        studentEmail: (map['studentEmail'] ?? '') as String,
        studentPhone: (map['studentPhone'] ?? '') as String,
        flavor: (map['flavor'] ?? '') as String,
        cakeType: (map['cakeType'] ?? '') as String,
        size: (map['size'] ?? '') as String,
        cream: (map['cream'] ?? '') as String,
        decorations: _stringList(map['decorations']),
        cakeMessage: (map['cakeMessage'] ?? '') as String,
        specialInstructions: (map['specialInstructions'] ?? '') as String,
        referenceImage: (map['referenceImage'] ?? '') as String,
        requiredDate: (map['requiredDate'] ?? '') as String,
        requiredTime: (map['requiredTime'] ?? '') as String,
        estimatedPrice: _intValue(map['estimatedPrice']),
        status: (map['status'] ?? '') as String,
        createdAt: (map['createdAt'] ?? '') as String,
        updatedAt: (map['updatedAt'] ?? '') as String,
      );

  static List<String> _stringList(dynamic value) {
    if (value is List) {
      return value.map((dynamic item) => item.toString()).toList();
    }
    return <String>[];
  }

  static int _intValue(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value) ?? 0;
    return 0;
  }
}
