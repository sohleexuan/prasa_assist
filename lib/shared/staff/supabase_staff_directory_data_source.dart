import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'src/staff_directory_transport_classifier.dart';
import 'staff_directory_data_source.dart';
import 'staff_directory_exception.dart';
import 'staff_profile.dart';

abstract interface class StaffDirectorySupabaseGateway {
  Future<Object?> invokeRpc(String functionName);
}

class SupabaseStaffDirectoryGateway implements StaffDirectorySupabaseGateway {
  SupabaseStaffDirectoryGateway(this._client);

  final SupabaseClient _client;

  @override
  Future<Object?> invokeRpc(String functionName) =>
      _client.rpc<Object?>(functionName);
}

class SupabaseStaffDirectoryDataSource
    implements StaffDirectoryRemoteDataSource {
  SupabaseStaffDirectoryDataSource(SupabaseClient client)
    : this.withGateway(SupabaseStaffDirectoryGateway(client));

  SupabaseStaffDirectoryDataSource.withGateway(this._gateway);

  static const directoryRpc = 'list_staff_directory';
  static const assignableStaffRpc = 'list_assignable_staff';

  final StaffDirectorySupabaseGateway _gateway;

  @override
  Future<List<StaffProfile>> fetchActiveDirectory() => _fetch(directoryRpc);

  @override
  Future<List<StaffProfile>> fetchAssignableStaff() =>
      _fetch(assignableStaffRpc);

  Future<List<StaffProfile>> _fetch(String functionName) async {
    try {
      final response = await _gateway.invokeRpc(functionName);
      if (response is! List) {
        throw StaffDirectoryMappingException(
          'The staff directory returned an invalid response.',
          cause: response,
        );
      }
      return List<StaffProfile>.unmodifiable(
        response.map((item) {
          if (item is! Map) {
            throw StaffDirectoryMappingException(
              'The staff directory contains an invalid record.',
              cause: item,
            );
          }
          final map = Map<String, dynamic>.from(item);
          return StaffProfile(
            userId: _text(map, 'user_id'),
            staffCode: _text(map, 'staff_code'),
            displayName: _text(map, 'display_name'),
            role: StaffRole.fromStorage(map['role']),
            active: true,
            version: _integer(map, 'version'),
          );
        }),
      );
    } on StaffDirectoryException {
      rethrow;
    } on AuthException catch (error) {
      throw StaffDirectoryPermissionException(
        'Authentication is required to access the staff directory.',
        cause: error,
      );
    } on PostgrestException catch (error) {
      if (error.code == '42501') {
        throw StaffDirectoryPermissionException(
          'This staff account cannot access the staff directory.',
          cause: error,
        );
      }
      throw StaffDirectoryException(
        'The staff directory request could not be completed safely.',
        cause: error,
      );
    } on TimeoutException catch (error) {
      throw StaffDirectoryOfflineException(
        'The staff directory service is unreachable.',
        cause: error,
      );
    } catch (error) {
      if (isStaffDirectoryConnectivityFailure(error)) {
        throw StaffDirectoryOfflineException(
          'The staff directory service is unreachable.',
          cause: error,
        );
      }
      throw StaffDirectoryException(
        'The staff directory request could not be completed safely.',
        cause: error,
      );
    }
  }

  String _text(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! String || value.trim().isEmpty) {
      throw StaffDirectoryMappingException(
        'The staff directory contains an invalid $key field.',
      );
    }
    return value.trim();
  }

  int _integer(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is! int || value < 1) {
      throw StaffDirectoryMappingException(
        'The staff directory contains an invalid $key field.',
      );
    }
    return value;
  }
}
