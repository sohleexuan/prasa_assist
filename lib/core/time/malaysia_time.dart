abstract final class MalaysiaTime {
  static const Duration utcOffset = Duration(hours: 8);
  static const String label = 'MYT';

  static DateTime instantToWallClock(DateTime instant) {
    final malaysiaInstant = instant.toUtc().add(utcOffset);
    return DateTime(
      malaysiaInstant.year,
      malaysiaInstant.month,
      malaysiaInstant.day,
      malaysiaInstant.hour,
      malaysiaInstant.minute,
      malaysiaInstant.second,
      malaysiaInstant.millisecond,
      malaysiaInstant.microsecond,
    );
  }

  static DateTime wallClockToUtc(DateTime wallClock) {
    return DateTime.utc(
      wallClock.year,
      wallClock.month,
      wallClock.day,
      wallClock.hour,
      wallClock.minute,
      wallClock.second,
      wallClock.millisecond,
      wallClock.microsecond,
    ).subtract(utcOffset);
  }

  static String formatDateTime(DateTime instant) {
    final wallClock = instantToWallClock(instant);
    return '${_date(wallClock)} ${_time(wallClock)} $label';
  }

  static String formatDate(DateTime instant) {
    final wallClock = instantToWallClock(instant);
    return '${_date(wallClock)} $label';
  }

  static String formatTime(DateTime instant) {
    final wallClock = instantToWallClock(instant);
    return '${_time(wallClock)} $label';
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static String _time(DateTime value) =>
      '${value.hour.toString().padLeft(2, '0')}:'
      '${value.minute.toString().padLeft(2, '0')}';
}
