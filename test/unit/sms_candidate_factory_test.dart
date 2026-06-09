import 'package:ai_expense_tracker/features/sms_suggestions/sms_candidate_factory.dart';
import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('smsBodyHash', () {
    test('returns a stable sha256 hash for the same body', () {
      // Arrange
      const body = 'HDFC Bank: Rs. 642.00 debited from A/c XX2182.';

      // Act
      final first = smsBodyHash(body);
      final second = smsBodyHash(body);

      // Assert
      expect(first, second);
      expect(first, hasLength(64));
    });
  });

  group('redactSmsPreview', () {
    test('redacts long numbers, account hints, and UPI handles', () {
      // Arrange
      const body =
          'Paid 9876543210 from A/c XX2182 to raexample@okhdfc ref 123456789012.';

      // Act
      final redacted = redactSmsPreview(body);

      // Assert
      expect(redacted, isNot(contains('9876543210')));
      expect(redacted, isNot(contains('XX2182')));
      expect(redacted, isNot(contains('raexample@okhdfc')));
      expect(redacted, contains('A/c ***'));
      expect(redacted, contains('ra***@okhdfc'));
    });
  });

  group('buildPendingSmsCandidate', () {
    test('creates a pending candidate with hashed and redacted SMS body', () {
      // Arrange
      final receivedAt = DateTime(2026, 6, 1, 10);
      final createdAt = DateTime(2026, 6, 1, 11);
      const body = 'HDFC Bank: Rs. 642.00 debited from A/c XX2182.';
      final parsed = ParsedExpense(
        amount: 642,
        currency: 'INR',
        date: receivedAt,
        payee: 'Swiggy',
        category: ExpenseCategory.food,
        confidence: 0.8,
        reason: 'Parsed on device.',
        isPersonLike: false,
      );

      // Act
      final candidate = buildPendingSmsCandidate(
        id: 'candidate-1',
        sender: 'HDFCBK',
        body: body,
        receivedAt: receivedAt,
        parsed: parsed,
        createdAt: createdAt,
      );

      // Assert
      expect(candidate.id, 'candidate-1');
      expect(candidate.sender, 'HDFCBK');
      expect(candidate.receivedAt, receivedAt);
      expect(candidate.createdAt, createdAt);
      expect(candidate.status, SmsCandidateStatus.pending);
      expect(candidate.proposedExpense.amount, parsed.amount);
      expect(candidate.proposedExpense.date, receivedAt);
      expect(candidate.modelReason, parsed.reason);
      expect(candidate.bodyHash, smsBodyHash(body));
      expect(candidate.redactedPreview, isNot(contains('XX2182')));
    });
  });
}
