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
