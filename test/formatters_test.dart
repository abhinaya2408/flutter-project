import 'package:college_bakery_flutter/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatDate', () {
    test('renders the en-IN long date', () {
      expect(Formatters.formatDate('2026-10-02'), '2 October 2026');
      expect(Formatters.formatDate('2026-01-15'), '15 January 2026');
    });

    test('empty and unparseable values', () {
      expect(Formatters.formatDate(''), '');
      expect(Formatters.formatDate(null), '');
      expect(Formatters.formatDate('not-a-date'), 'not-a-date');
    });
  });

  group('formatTime', () {
    test('12-hour clock', () {
      expect(Formatters.formatTime('16:00'), '4:00 PM');
      expect(Formatters.formatTime('11:30'), '11:30 AM');
      expect(Formatters.formatTime('00:05'), '12:05 AM');
      expect(Formatters.formatTime('12:00'), '12:00 PM');
      expect(Formatters.formatTime('18:00'), '6:00 PM');
    });

    test('empty values', () {
      expect(Formatters.formatTime(''), '');
      expect(Formatters.formatTime(null), '');
    });
  });

  group('timeAgo', () {
    String isoAgo(Duration duration) =>
        DateTime.now().toUtc().subtract(duration).toIso8601String();

    test('just now, minutes, hours and days', () {
      expect(Formatters.timeAgo(isoAgo(const Duration(seconds: 20))), 'just now');
      expect(Formatters.timeAgo(isoAgo(const Duration(minutes: 5))), '5m ago');
      expect(Formatters.timeAgo(isoAgo(const Duration(hours: 3))), '3h ago');
      expect(Formatters.timeAgo(isoAgo(const Duration(days: 2))), '2d ago');
    });

    test('empty values', () {
      expect(Formatters.timeAgo(''), '');
      expect(Formatters.timeAgo(null), '');
    });
  });

  group('statusLabel', () {
    test('maps every status', () {
      expect(Formatters.statusLabel('PENDING'), 'Pending');
      expect(Formatters.statusLabel('ACCEPTED'), 'Accepted');
      expect(Formatters.statusLabel('PREPARING'), 'Preparing');
      expect(Formatters.statusLabel('READY'), 'Ready');
      expect(Formatters.statusLabel('COLLECTED'), 'Collected');
      expect(Formatters.statusLabel('COMPLETED'), 'Completed');
      expect(Formatters.statusLabel('REJECTED'), 'Rejected');
    });
  });

  group('helpers', () {
    test('fileSize rounds to KB', () {
      expect(Formatters.fileSize(2048), '2 KB');
      expect(Formatters.fileSize(1536), '2 KB');
    });

    test('dateOnly / timeValue / today', () {
      expect(Formatters.dateOnly(DateTime(2026, 10, 2)), '2026-10-02');
      expect(Formatters.timeValue(9, 5), '09:05');
      expect(Formatters.timeValue(16, 0), '16:00');
      expect(Formatters.today(), Formatters.dateOnly(DateTime.now()));
    });

    test('formatIsoDate matches formatDate for the same day', () {
      final String iso = DateTime(2026, 10, 2, 15, 30).toIso8601String();
      expect(Formatters.formatIsoDate(iso), '2 October 2026');
    });
  });
}
