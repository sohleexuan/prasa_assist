import '../../../core/time/malaysia_time.dart';

String formatDeploymentLocalDateTime(DateTime value) {
  return MalaysiaTime.formatDateTime(value);
}

String formatDeploymentLocalDate(DateTime value) {
  return MalaysiaTime.formatDate(value);
}

String formatDeploymentLocalTime(DateTime value) {
  return MalaysiaTime.formatTime(value);
}
