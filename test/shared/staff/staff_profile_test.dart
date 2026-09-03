import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/shared/staff/staff_profile.dart';

void main() {
  test('uses the approved display name and staff code label', () {
    final profile = StaffProfile(
      userId: '22222222-2222-4222-8222-222222222222',
      staffCode: ' m-002 ',
      displayName: ' Maintenance One ',
      role: StaffRole.maintenanceStaff,
      active: true,
      version: 1,
    );

    expect(profile.displayLabel, 'Maintenance One (M-002)');
    expect(profile.staffCode, 'M-002');
    expect(profile.isAssignable, isTrue);
  });

  test('rejects blank labels, invalid UUIDs and invalid versions', () {
    expect(
      () => StaffProfile(
        userId: 'invalid',
        staffCode: 'M-002',
        displayName: 'Maintenance One',
        role: StaffRole.maintenanceStaff,
        active: true,
        version: 1,
      ),
      throwsArgumentError,
    );
    expect(
      () => StaffProfile(
        userId: '22222222-2222-4222-8222-222222222222',
        staffCode: ' ',
        displayName: 'Maintenance One',
        role: StaffRole.maintenanceStaff,
        active: true,
        version: 1,
      ),
      throwsFormatException,
    );
    expect(
      () => StaffProfile(
        userId: '22222222-2222-4222-8222-222222222222',
        staffCode: 'M-002',
        displayName: 'Maintenance One',
        role: StaffRole.maintenanceStaff,
        active: true,
        version: 0,
      ),
      throwsFormatException,
    );
  });

  test('ordinary fallback never reveals UUID or email', () {
    expect(
      safeStaffDisplayLabel('22222222-2222-4222-8222-222222222222'),
      staffProfileUnavailableLabel,
    );
    expect(
      safeStaffDisplayLabel('staff@example.test'),
      staffProfileUnavailableLabel,
    );
    expect(
      safeStaffDisplayLabel('Supervisor One (S-001)'),
      'Supervisor One (S-001)',
    );
    expect(safeStaffDisplayLabel('Operations @ Depot'), 'Operations @ Depot');
    expect(
      safeStaffDisplayLabel('Staff 22222222-2222-4222-8222-222222222222'),
      'Staff 22222222-2222-4222-8222-222222222222',
    );
  });
}
