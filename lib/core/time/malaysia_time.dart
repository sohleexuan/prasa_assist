/// Device-timezone-independent conversions between UTC instants and Malaysia
/// wall-clock values.
///
/// Persistence values remain UTC. A wall-clock value returned by
/// [instantToWallClock] carries Malaysia date/time components for picker use;
/// pass it back through [wallClockToUtc] instead of calling `toUtc()` on it.
abstract final class MalaysiaTime {
  static const Duration utcOffset = Duration(hours: 8);
  static const String label = 'MYT';

  /// Converts an instant to a DateTime whose components represent Malaysia
  /// wall-clock time, without consulting the device timezone.
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

  /// Interprets [wallClock]'s components as Malaysia time and returns the UTC
  /// instant. Its `isUtc` kind is deliberately ignored to avoid double shifts.
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
