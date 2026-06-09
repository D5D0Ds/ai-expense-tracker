import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Architecture boundaries', () {
    test(
      'reports and SMS depend on the expenses API, not expenses internals',
      () {
        // Arrange
        final files = [
          File('lib/features/reports/reports_controller.dart'),
          File('lib/features/reports/reports_screen.dart'),
          File('lib/features/reports/report_export_service.dart'),
          File('lib/features/sms_suggestions/sms_suggestions_controller.dart'),
        ];

        // Act
        final imports = files.expand((file) {
          return file.readAsLinesSync().where(
            (line) => line.trimLeft().startsWith('import '),
          );
        }).toList();

        // Assert
        expect(
          imports,
          isNot(
            contains(
              contains('features/expenses/expense_controller.dart'),
            ),
          ),
        );
        expect(
          imports,
          isNot(
            contains(
              contains('features/expenses/expense_repository.dart'),
            ),
          ),
        );
      },
    );

    test('feature UI depends on app permission gateway, not plugin API', () {
      // Arrange
      final files = [
        File('lib/features/settings/settings_screen.dart'),
        File('lib/features/sms_suggestions/sms_suggestions_screen.dart'),
      ];

      // Act
      final source = files.map((file) => file.readAsStringSync()).join('\n');

      // Assert
      expect(source, isNot(contains('permission_handler')));
      expect(source, contains('permission_gateway.dart'));
    });

    test(
      'SMS controller uses platform gateway provider, not bridge concrete',
      () {
        // Arrange
        final source = File(
          'lib/features/sms_suggestions/sms_suggestions_controller.dart',
        ).readAsStringSync();

        // Assert
        expect(source, contains('smsGatewayProvider'));
        expect(source, isNot(contains('NativeSmsBridge')));
      },
    );
  });
}
