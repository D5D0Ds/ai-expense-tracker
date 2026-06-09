import 'package:ai_expense_tracker/shared/theme/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AppTheme', () {
    test('defines correct color tokens', () {
      expect(AppTheme.background, const Color(0xFF040607));
      expect(AppTheme.accent, const Color(0xFFFFFFFF));
    });

    test('dark theme is generated correctly', () {
      final theme = AppTheme.dark;
      expect(theme.brightness, Brightness.dark);
      expect(theme.colorScheme.background, AppTheme.background);
      expect(theme.colorScheme.foreground, AppTheme.textPrimary);
    });
  });
}
