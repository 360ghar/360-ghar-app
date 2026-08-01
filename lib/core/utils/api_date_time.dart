final RegExp _offsetOrZuluSuffix = RegExp(r'([zZ]|[+-]\d{2}:\d{2})$');
final RegExp _dateOnlyPattern = RegExp(r'^\d{4}-\d{2}-\d{2}$');

String? _normalizeServerTimestamp(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) return null;
  if (trimmed.contains('T') && !_offsetOrZuluSuffix.hasMatch(trimmed)) {
    return '${trimmed}Z';
  }
  return trimmed;
}

DateTime? parseApiDateTime(dynamic value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is String) {
    final normalized = _normalizeServerTimestamp(value);
    if (normalized == null) return null;
    if (_dateOnlyPattern.hasMatch(normalized)) {
      final parts = normalized.split('-');
      return DateTime.utc(int.parse(parts[0]), int.parse(parts[1]), int.parse(parts[2]));
    }
    return DateTime.tryParse(normalized);
  }
  return null;
}

DateTime? combineUtcDateAndTime(String? date, String? time) {
  final dateValue = date?.trim();
  final timeValue = time?.trim();
  if (dateValue == null || dateValue.isEmpty) return null;
  if (timeValue == null || timeValue.isEmpty) return parseApiDateTime(dateValue);

  final dateParts = dateValue.split('-');
  final timeParts = timeValue.split(':');
  if (dateParts.length != 3 || timeParts.length < 2) return null;

  final year = int.tryParse(dateParts[0]);
  final month = int.tryParse(dateParts[1]);
  final day = int.tryParse(dateParts[2]);
  final hour = int.tryParse(timeParts[0]);
  final minute = int.tryParse(timeParts[1]);
  final second = timeParts.length > 2 ? int.tryParse(timeParts[2]) ?? 0 : 0;

  if (year == null || month == null || day == null || hour == null || minute == null) {
    return null;
  }

  return DateTime.utc(year, month, day, hour, minute, second);
}

String? formatDateOnlyForApi(DateTime? value) {
  if (value == null) return null;
  final year = value.year.toString().padLeft(4, '0');
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');
  return '$year-$month-$day';
}

String? toApiUtcInstant(DateTime? value) {
  if (value == null) return null;
  return value.toUtc().toIso8601String();
}

/// Formats [date] as `dd/MM/yyyy` for user-facing display (date pickers,
/// visit cards, profile screens). The canonical form for date-picker labels.
String formatDisplayDate(DateTime date) {
  String two(int v) => v.toString().padLeft(2, '0');
  return '${two(date.day)}/${two(date.month)}/${date.year}';
}
