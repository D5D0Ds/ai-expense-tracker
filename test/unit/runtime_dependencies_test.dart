import 'package:ai_expense_tracker/shared/core/runtime_dependencies.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Runtime Dependencies Providers', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('nowProvider returns a function that returns current time', () {
      final nowFunc = container.read(nowProvider);
      final before = DateTime.now();
      final time = nowFunc();
      final after = DateTime.now();

      expect(time.isAfter(before.subtract(const Duration(seconds: 1))), isTrue);
      expect(time.isBefore(after.add(const Duration(seconds: 1))), isTrue);
    });

    test('idGeneratorProvider returns a function that generates v4 UUIDs', () {
      final idFunc = container.read(idGeneratorProvider);
      final id1 = idFunc();
      final id2 = idFunc();

      expect(id1, isNotEmpty);
      expect(id2, isNotEmpty);
      expect(id1, isNot(id2));
      // Standard UUID v4 regex check
      expect(
        RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$').hasMatch(id1),
        isTrue,
      );
    });
  });
}
