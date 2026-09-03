import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/shared/staff/staff_directory_exception.dart';
import 'package:prasa_assist/shared/staff/supabase_staff_directory_data_source.dart';

void main() {
  test(
    'maps only approved directory fields and ignores email metadata',
    () async {
      final gateway = _Gateway([
        {
          'user_id': '22222222-2222-4222-8222-222222222222',
          'staff_code': 'M-002',
          'display_name': 'Maintenance One',
          'role': 'maintenance_staff',
          'version': 2,
          'email': 'must-not-enter-domain@example.test',
        },
      ]);
      final source = SupabaseStaffDirectoryDataSource.withGateway(gateway);

      final profiles = await source.fetchActiveDirectory();

      expect(gateway.functionName, 'list_staff_directory');
      expect(profiles.single.displayLabel, 'Maintenance One (M-002)');
      expect(profiles.single.toString(), isNot(contains('@')));
    },
  );

  test('assignment directory uses the restricted assignable RPC', () async {
    final gateway = _Gateway([
      {
        'user_id': '22222222-2222-4222-8222-222222222222',
        'staff_code': 'm-002',
        'display_name': 'Maintenance One',
        'role': 'maintenance_staff',
        'version': 2,
      },
    ]);
    final source = SupabaseStaffDirectoryDataSource.withGateway(gateway);

    final profiles = await source.fetchAssignableStaff();

    expect(gateway.functionName, 'list_assignable_staff');
    expect(profiles.single.staffCode, 'M-002');
    expect(profiles.single.isAssignable, isTrue);
  });

  test('rejects malformed directory records safely', () async {
    final source = SupabaseStaffDirectoryDataSource.withGateway(
      _Gateway([
        {'user_id': 'not-a-uuid'},
      ]),
    );

    await expectLater(
      source.fetchActiveDirectory(),
      throwsA(isA<StaffDirectoryException>()),
    );
  });
}

class _Gateway implements StaffDirectorySupabaseGateway {
  _Gateway(this.response);

  final Object? response;
  String? functionName;

  @override
  Future<Object?> invokeRpc(String functionName) async {
    this.functionName = functionName;
    return response;
  }
}
