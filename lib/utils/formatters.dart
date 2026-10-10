/// Formatting helpers — direct ports of the helpers at the bottom of
/// `college-bakery/js/app.js`.
class Formatters {
  Formatters._();

  static const List<String> _months = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];

  /// `formatDate()` — `toLocaleDateString("en-IN", { day: "numeric",
  /// month: "long", year: "numeric" })` → e.g. `2 October 2026`.
  static String formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';
    final DateTime? parsed = parseDateOnly(dateStr);
    if (parsed == null) return dateStr;
    return '${parsed.day} ${_months[parsed.month - 1]} ${parsed.year}';
  }

  /// Same output as [formatDate] but for a full ISO date-time string — used by
  /// the order details header (`Placed on …`).
  static String formatIsoDate(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final DateTime? parsed = DateTime.tryParse(isoString);
    if (parsed == null) return isoString;
    final DateTime local = parsed.toLocal();
    return '${local.day} ${_months[local.month - 1]} ${local.year}';
  }

  /// `formatTime()` — `"16:00"` → `"4:00 PM"`.
  static String formatTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return '';
    final List<String> parts = timeStr.split(':');
    if (parts.length < 2) return timeStr;
    final int? hour = int.tryParse(parts[0]);
    if (hour == null) return timeStr;
    final String minutes = parts[1];
    final String period = hour >= 12 ? 'PM' : 'AM';
    final int displayHour = ((hour + 11) % 12) + 1;
    return '$displayHour:$minutes $period';
  }

  /// `timeAgo()` — `"just now"`, `"3m ago"`, `"5h ago"`, `"2d ago"`.
  static String timeAgo(String? isoString) {
    if (isoString == null || isoString.isEmpty) return '';
    final DateTime? parsed = DateTime.tryParse(isoString);
    if (parsed == null) return '';
    final int diffMs = DateTime.now().difference(parsed).inMilliseconds;
    final int mins = diffMs ~/ 60000;
    if (mins < 1) return 'just now';
    if (mins < 60) return '${mins}m ago';
    final int hrs = mins ~/ 60;
    if (hrs < 24) return '${hrs}h ago';
    final int days = hrs ~/ 24;
    return '${days}d ago';
  }

  /// `statusLabel()` — the label map from `js/app.js`.
  static String statusLabel(String? status) {
    const Map<String, String> map = <String, String>{
      'PENDING': 'Pending',
      'ACCEPTED': 'Accepted',
      'PREPARING': 'Preparing',
      'READY': 'Ready',
      'COLLECTED': 'Collected',
      'COMPLETED': 'Completed',
      'REJECTED': 'Rejected',
    };
    return map[status] ?? (status ?? '');
  }

  /// `(file.size / 1024).toFixed(0) + " KB"`
  static String fileSize(int bytes) => '${(bytes / 1024).round()} KB';

  /// `<input type="date">` value → `"YYYY-MM-DD"`.
  static String dateOnly(DateTime date) {
    final String month = date.month.toString().padLeft(2, '0');
    final String day = date.day.toString().padLeft(2, '0');
    return '${date.year}-$month-$day';
  }

  /// `<input type="time">` value → `"HH:mm"` (24-hour, zero padded).
  static String timeValue(int hour, int minute) {
    final String h = hour.toString().padLeft(2, '0');
    final String m = minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  /// Today's `new Date().toISOString().slice(0, 10)` equivalent.
  static String today() => dateOnly(DateTime.now());

  /// Parses `"YYYY-MM-DD"` the way `new Date(dateStr + "T00:00:00")` would.
  static DateTime? parseDateOnly(String value) {
    final List<String> parts = value.split('-');
    if (parts.length != 3) return null;
    final int? year = int.tryParse(parts[0]);
    final int? month = int.tryParse(parts[1]);
    final int? day = int.tryParse(parts[2]);
    if (year == null || month == null || day == null) return null;
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    return DateTime(year, month, day);
  }
}
