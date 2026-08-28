String formatDeploymentLocalDateTime(DateTime value) {
  final local = value.toLocal();
  return '${formatDeploymentLocalDate(local)} '
      '${formatDeploymentLocalTime(local)}';
}

String formatDeploymentLocalDate(DateTime value) {
  final local = value.toLocal();
  return '${local.year.toString().padLeft(4, '0')}-'
      '${local.month.toString().padLeft(2, '0')}-'
      '${local.day.toString().padLeft(2, '0')}';
}

String formatDeploymentLocalTime(DateTime value) {
  final local = value.toLocal();
  return '${local.hour.toString().padLeft(2, '0')}:'
      '${local.minute.toString().padLeft(2, '0')}';
}
