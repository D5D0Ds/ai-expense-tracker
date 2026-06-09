import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

/// Provides the current time.
final nowProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Provides unique ids.
final idGeneratorProvider = Provider<String Function()>((ref) {
  const uuid = Uuid();
  return uuid.v4;
});
