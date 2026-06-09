import 'dart:convert';

import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:crypto/crypto.dart';

/// Creates an SMS body hash for deduplication.
String smsBodyHash(String body) {
  return sha256.convert(utf8.encode(body)).toString();
}

/// Redacts sensitive account and handle data from an SMS preview.
String redactSmsPreview(String body) {
  return body
      .replaceAll(RegExp(r'\b[0-9]{10,}\b'), '***')
      .replaceAllMapped(
        RegExp(r'(A/c|Acct|account)\s*[A-Za-z0-9*Xx]+'),
        (match) => '${match.group(1)} ***',
      )
      .replaceAllMapped(
        RegExp(r'([A-Za-z0-9._-]{2})[A-Za-z0-9._-]+@([A-Za-z]{2,})'),
        (match) => '${match.group(1)}***@${match.group(2)}',
      );
}

/// Builds a pending SMS candidate from parsed model output.
SmsCandidate buildPendingSmsCandidate({
  required String id,
  required String sender,
  required String body,
  required DateTime receivedAt,
  required ParsedExpense parsed,
  required DateTime createdAt,
}) {
  return SmsCandidate(
    id: id,
    sender: sender,
    receivedAt: receivedAt,
    bodyHash: smsBodyHash(body),
    redactedPreview: redactSmsPreview(body),
    status: SmsCandidateStatus.pending,
    proposedExpense: parsed.copyWith(date: receivedAt),
    modelReason: parsed.reason,
    createdAt: createdAt,
  );
}
