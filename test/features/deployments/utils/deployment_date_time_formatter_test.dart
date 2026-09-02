import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/deployments/utils/deployment_date_time_formatter.dart';

void main() {
  test('formats UTC instants with fixed Malaysia date and time fields', () {
    final utc = DateTime.utc(2026, 8, 27, 20, 40);

    expect(formatDeploymentLocalDateTime(utc), '2026-08-28 04:40 MYT');
    expect(formatDeploymentLocalDate(utc), '2026-08-28 MYT');
    expect(formatDeploymentLocalTime(utc), '04:40 MYT');
  });
}
