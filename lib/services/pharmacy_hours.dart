class PharmacyHours {
  /// The manually toggled open/closed state, or null when the pharmacy is
  /// following its schedule. Stored at `hours._manualOpen` so the customer
  /// app (which reads the same field) stays in sync.
  static bool? manualOpen(Map<String, dynamic> data) {
    final hours = data['hours'];
    if (hours is Map && hours.containsKey('_manualOpen')) {
      return hours['_manualOpen'] == true;
    }
    return null;
  }

  static bool hasManualOverride(Map<String, dynamic> data) =>
      manualOpen(data) != null;

  static bool isOpenNow(Map<String, dynamic> data) {
    final manual = manualOpen(data);
    if (manual != null) return manual;

    final now = DateTime.now();
    final isWeekend = now.weekday == 6 || now.weekday == 7;

    final openStr = isWeekend
        ? data['weekendOpen'] as String?
        : data['weekdayOpen'] as String?;
    final closeStr = isWeekend
        ? data['weekendClose'] as String?
        : data['weekdayClose'] as String?;

    if (openStr == null || closeStr == null) return false;

    final open = _parseTime(openStr);
    final close = _parseTime(closeStr);
    if (open == null || close == null) return false;

    final currentMinutes = now.hour * 60 + now.minute;
    final openMinutes = open.hour * 60 + open.minute;
    final closeMinutes = close.hour * 60 + close.minute;

    if (openMinutes < closeMinutes) {
      return currentMinutes >= openMinutes && currentMinutes < closeMinutes;
    } else {
      return currentMinutes >= openMinutes || currentMinutes < closeMinutes;
    }
  }

  static _ParsedTime? _parseTime(String timeStr) {
    final parts = timeStr.split(':');
    if (parts.length != 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    return _ParsedTime(hour, minute);
  }
}

class _ParsedTime {
  final int hour;
  final int minute;
  const _ParsedTime(this.hour, this.minute);
}
