import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/time/malaysia_time.dart';

void main() {
  group('MalaysiaTime.formatDateTime', () {
    test('converts 20:30 UTC to 04:30 MYT on the next day', () {
      expect(
        MalaysiaTime.formatDateTime(DateTime.utc(2026, 9, 1, 20, 30)),
        '2026-09-02 04:30 MYT',
      );
    });

    test('converts 22:30 UTC to 06:30 MYT on the next day', () {
      expect(
        MalaysiaTime.formatDateTime(DateTime.utc(2026, 9, 1, 22, 30)),
        '2026-09-02 06:30 MYT',
      );
    });

    test('crosses a month boundary', () {
      expect(
        MalaysiaTime.formatDateTime(DateTime.utc(2026, 1, 31, 20, 15)),
        '2026-02-01 04:15 MYT',
      );
    });

    test('crosses a year boundary', () {
      expect(
        MalaysiaTime.formatDateTime(DateTime.utc(2026, 12, 31, 20, 45)),
        '2027-01-01 04:45 MYT',
      );
    });

    test('crosses onto leap day', () {
      expect(
        MalaysiaTime.formatDateTime(DateTime.utc(2024, 2, 28, 20, 5)),
        '2024-02-29 04:05 MYT',
      );
    });
  });

  test('picker and display round trip preserves the UTC instant', () {
    final original = DateTime.utc(2026, 9, 1, 20, 30, 45, 123, 456);

    final wallClock = MalaysiaTime.instantToWallClock(original);
    final restored = MalaysiaTime.wallClockToUtc(wallClock);

    expect(wallClock, DateTime(2026, 9, 2, 4, 30, 45, 123, 456));
    expect(restored, original);
    expect(restored.isUtc, isTrue);
  });

  test('wall-clock conversion ignores the DateTime kind', () {
    final localKind = DateTime(2026, 9, 2, 4, 30);
    final utcKind = DateTime.utc(2026, 9, 2, 4, 30);

    expect(
      MalaysiaTime.wallClockToUtc(localKind),
      DateTime.utc(2026, 9, 1, 20, 30),
    );
    expect(
      MalaysiaTime.wallClockToUtc(utcKind),
      DateTime.utc(2026, 9, 1, 20, 30),
    );
  });

  test('display remains correct for a device-local DateTime instant', () {
    final utc = DateTime.utc(2026, 9, 1, 20, 30);
    final deviceLocal = utc.toLocal();

    expect(MalaysiaTime.formatDateTime(deviceLocal), '2026-09-02 04:30 MYT');
    expect(
      MalaysiaTime.instantToWallClock(deviceLocal),
      DateTime(2026, 9, 2, 4, 30),
    );
  });

  test('date and time formatters include the Malaysia timezone label', () {
    final utc = DateTime.utc(2026, 9, 1, 20, 30);

    expect(MalaysiaTime.formatDate(utc), '2026-09-02 MYT');
    expect(MalaysiaTime.formatTime(utc), '04:30 MYT');
  });
}
