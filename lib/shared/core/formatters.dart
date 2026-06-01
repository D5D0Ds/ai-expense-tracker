import 'package:intl/intl.dart';

/// Formats INR money values for compact mobile UI.
final inrFormat = NumberFormat.currency(
  locale: 'en_IN',
  symbol: '₹',
  decimalDigits: 0,
);

/// Formats a month heading.
final monthFormat = DateFormat('MMMM yyyy');

/// Formats transaction dates.
final transactionDateFormat = DateFormat('d MMM, h:mm a');

/// Formats bytes per second.
String formatSpeed(double bytesPerSecond) {
  if (bytesPerSecond <= 0) return '0 KB/s';
  final mb = bytesPerSecond / (1024 * 1024);
  if (mb >= 1) return '${mb.toStringAsFixed(1)} MB/s';
  return '${(bytesPerSecond / 1024).toStringAsFixed(0)} KB/s';
}

/// Formats durations for download ETA.
String formatEta(Duration? duration) {
  if (duration == null) return '--';
  if (duration.inHours > 0)
    return '${duration.inHours}h ${duration.inMinutes % 60}m';
  if (duration.inMinutes > 0)
    return '${duration.inMinutes}m ${duration.inSeconds % 60}s';
  return '${duration.inSeconds}s';
}
