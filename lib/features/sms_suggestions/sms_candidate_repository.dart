import 'package:ai_expense_tracker/shared/core/domain_models.dart';
import 'package:ai_expense_tracker/shared/persistence/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Provides SMS candidate persistence.
final smsCandidateRepositoryProvider = Provider<SmsCandidateRepository>((ref) {
  return SmsCandidateRepository(ref.watch(appDatabaseProvider));
});

/// Repository that stores SMS candidates awaiting user review.
final class SmsCandidateRepository {
  /// Creates a repository.
  SmsCandidateRepository(this._database);

  final AppDatabase _database;

  /// Returns all suggestions ordered newest first.
  Future<List<SmsCandidate>> all() async {
    final candidates =
        _database.smsCandidates.values
            .whereType<Map<dynamic, dynamic>>()
            .map(SmsCandidate.fromJson)
            .toList()
          ..sort((a, b) => b.receivedAt.compareTo(a.receivedAt));
    return candidates;
  }

  /// Returns pending suggestions.
  Future<List<SmsCandidate>> pending() async {
    final candidates = await all();
    return candidates
        .where((candidate) => candidate.status == SmsCandidateStatus.pending)
        .toList();
  }

  /// Finds a suggestion by id.
  Future<SmsCandidate?> byId(String id) async {
    final value = _database.smsCandidates.get(id);
    if (value is! Map<dynamic, dynamic>) return null;
    return SmsCandidate.fromJson(value);
  }

  /// Returns whether the SMS hash already exists.
  Future<bool> containsHash(String bodyHash) async {
    final candidates = await all();
    return candidates.any((candidate) => candidate.bodyHash == bodyHash);
  }

  /// Adds or replaces a candidate.
  Future<void> upsert(SmsCandidate candidate) async {
    await _database.smsCandidates.put(candidate.id, candidate.toJson());
  }
}
