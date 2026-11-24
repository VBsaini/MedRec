import 'package:intl/intl.dart';

final _display = DateFormat('d MMM yyyy');
final _displayTime = DateFormat('d MMM yyyy, h:mm a');
final _wire = DateFormat('yyyy-MM-dd');

/// Parses a calendar date from the API ("2023-01-15T00:00:00.000Z").
///
/// Dates such as a surgery date are stored as midnight UTC, so they are read
/// back in UTC: converting to local time could shift them to the previous day.
DateTime? parseDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  final parsed = DateTime.tryParse(value)?.toUtc();
  if (parsed == null) return null;
  return DateTime(parsed.year, parsed.month, parsed.day);
}

/// "15 Jan 2023", or an empty string for null.
String formatDate(DateTime? date) => date == null ? '' : _display.format(date);

/// A calendar date in the form the API expects ("2023-01-15").
String dateToWire(DateTime? date) => date == null ? '' : _wire.format(date);

/// Formats a real point in time (e.g. when a card was scanned) in local time.
String formatTimestamp(Object? value) {
  if (value is! String) return '';
  final parsed = DateTime.tryParse(value);
  return parsed == null ? '' : _displayTime.format(parsed.toLocal());
}

String formatFileSize(int? bytes) {
  if (bytes == null) return '';
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
}
