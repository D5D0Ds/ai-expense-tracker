import 'package:ai_expense_tracker/shared/persistence/app_database.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';

/// In-memory Hive box test double for repository/controller tests.
final class FakeBox implements Box<dynamic> {
  final Map<dynamic, dynamic> _data = {};

  @override
  dynamic get(dynamic key, {dynamic defaultValue}) {
    return _data[key] ?? defaultValue;
  }

  /// Stores a value without going through the async Box API.
  void seed(dynamic key, dynamic value) {
    _data[key] = value;
  }

  @override
  Future<void> put(dynamic key, dynamic value) async {
    _data[key] = value;
  }

  @override
  Future<void> delete(dynamic key) async {
    _data.remove(key);
  }

  @override
  Iterable<dynamic> get values => _data.values;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.memberName == #get) {
      return get(
        invocation.positionalArguments[0],
        defaultValue: invocation.namedArguments[#defaultValue],
      );
    }
    if (invocation.memberName == #put) {
      return put(
        invocation.positionalArguments[0],
        invocation.positionalArguments[1],
      );
    }
    if (invocation.memberName == #delete) {
      return delete(invocation.positionalArguments[0]);
    }
    if (invocation.memberName == #values) return values;
    throw UnimplementedError(
      'FakeBox: ${invocation.memberName} is not implemented',
    );
  }
}

/// In-memory app database test double.
final class FakeAppDatabase implements AppDatabase {
  /// Creates a fake database.
  FakeAppDatabase({
    Box<dynamic>? expenses,
    Box<dynamic>? smsCandidates,
    Box<dynamic>? settings,
  }) : expenses = expenses ?? FakeBox(),
       smsCandidates = smsCandidates ?? FakeBox(),
       settings = settings ?? FakeBox();

  @override
  final Box<dynamic> expenses;

  @override
  final Box<dynamic> smsCandidates;

  @override
  final Box<dynamic> settings;
}
