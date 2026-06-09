import 'package:ai_expense_tracker/shared/core/formatters.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Formatters', () {
    test('inrFormat formats currency correctly', () {
      expect(inrFormat.format(1200), '₹1,200');
      expect(inrFormat.format(0), '₹0');
    });

    test('monthFormat formats month correctly', () {
      final date = DateTime(2026, 6, 9);
      expect(monthFormat.format(date), 'June 2026');
    });

    test('transactionDateFormat formats date and time correctly', () {
      final date = DateTime(2026, 6, 9, 14, 30);
      expect(transactionDateFormat.format(date), '9 Jun, 2:30 PM');
    });

    test('formatSpeed formats transfer speed appropriately', () {
      expect(formatSpeed(0), '0 KB/s');
      expect(formatSpeed(-10), '0 KB/s');
      expect(formatSpeed(512 * 1024), '512 KB/s');
      expect(formatSpeed(1.5 * 1024 * 1024), '1.5 MB/s');
      expect(formatSpeed(10 * 1024 * 1024), '10.0 MB/s');
    });

    test('formatEta formats ETA durations correctly', () {
      expect(formatEta(null), '--');
      expect(formatEta(const Duration(seconds: 45)), '45s');
      expect(formatEta(const Duration(minutes: 3, seconds: 20)), '3m 20s');
      expect(formatEta(const Duration(hours: 2, minutes: 15, seconds: 30)), '2h 15m');
    });
  });
}
