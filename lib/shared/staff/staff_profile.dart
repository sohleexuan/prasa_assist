import '../../core/database/local_user_scope.dart';

enum StaffRole {
  operationsStaff('operations_staff'),
  maintenanceStaff('maintenance_staff'),
  supervisor('supervisor'),
  controlCentre('control_centre');

  const StaffRole(this.storageValue);

  final String storageValue;

  static StaffRole fromStorage(Object? value) => switch (value) {
    'operations_staff' => StaffRole.operationsStaff,
    'maintenance_staff' => StaffRole.maintenanceStaff,
    'supervisor' => StaffRole.supervisor,
    'control_centre' => StaffRole.controlCentre,
    _ => throw FormatException('Unknown staff role.'),
  };
}

class StaffProfile {
  StaffProfile({
    required String userId,
    required String staffCode,
    required String displayName,
    required this.role,
    required this.active,
    required this.version,
  }) : userId = LocalUserScope(userId).ownerUserId,
       staffCode = _required(staffCode, 'Staff code').toUpperCase(),
       displayName = _required(displayName, 'Display name') {
    if (version < 1) throw const FormatException('Invalid staff version.');
  }

  final String userId;
  final String staffCode;
  final String displayName;
  final StaffRole role;
  final bool active;
  final int version;

  String get displayLabel => '$displayName ($staffCode)';

  bool get isAssignable => active && role == StaffRole.maintenanceStaff;

  static String _required(String value, String label) {
    final normalized = value.trim();
    if (normalized.isEmpty) throw FormatException('$label is required.');
    return normalized;
  }

  @override
  bool operator ==(Object other) =>
      other is StaffProfile &&
      userId == other.userId &&
      staffCode == other.staffCode &&
      displayName == other.displayName &&
      role == other.role &&
      active == other.active &&
      version == other.version;

  @override
  int get hashCode =>
      Object.hash(userId, staffCode, displayName, role, active, version);
}

const staffProfileUnavailableLabel = 'Staff profile unavailable';
const legacyAssignmentUnverifiedLabel = 'Legacy assignment — unverified';

String safeStaffDisplayLabel(String? value) {
  final normalized = value?.trim();
  if (normalized == null ||
      normalized.isEmpty ||
      _emailPattern.hasMatch(normalized) ||
      _uuidPattern.hasMatch(normalized)) {
    return staffProfileUnavailableLabel;
  }
  return normalized;
}

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

final RegExp _uuidPattern = RegExp(
  r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-'
  r'[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
);
