import 'package:ai_expense_tracker/app/app.dart';
import 'package:ai_expense_tracker/shared/persistence/app_database.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

/// Initializes services that must exist before the first Flutter frame.
Future<void> bootstrap() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = true;

  final database = await AppDatabase.open();

  runApp(
    ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(database),
      ],
      child: const ExpenseTrackerApp(),
    ),
  );
}
