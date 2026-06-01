import 'package:ai_expense_tracker/shared/core/text_normalization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('trimToNull', () {
    test('returns null for null or blank values', () {
      // Act / Assert
      expect(trimToNull(null), isNull);
      expect(trimToNull(''), isNull);
      expect(trimToNull('   '), isNull);
    });

    test('returns trimmed text for non-blank values', () {
      // Act
      final result = trimToNull('  Grocery Store  ');

      // Assert
      expect(result, 'Grocery Store');
    });
  });
}
