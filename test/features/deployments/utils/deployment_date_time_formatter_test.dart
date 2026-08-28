import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/utils/deployment_date_time_formatter.dart';

void main() {
  test('formats UTC instants with device-local date and time fields', () {
    final utc = DateTime.utc(2026, 8, 27, 20, 40);
    final local = utc.toLocal();

    expect(formatDeploymentLocalDateTime(utc), _dateTimeText(local));
    expect(formatDeploymentLocalDate(utc), _dateText(local));
    expect(formatDeploymentLocalTime(utc), _timeText(local));
  });
}

String _dateTimeText(DateTime value) =>
    '${_dateText(value)} ${_timeText(value)}';

String _dateText(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _timeText(DateTime value) =>
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';
