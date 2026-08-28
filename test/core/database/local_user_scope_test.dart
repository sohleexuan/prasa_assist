import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/local_user_scope.dart';

void main() {
  group('LocalUserScope', () {
    test('uses the authenticated Supabase UUID as ownerUserId', () {
      final scope = LocalUserScope(' 11111111-1111-4111-8111-111111111111 ');

      expect(scope.ownerUserId, '11111111-1111-4111-8111-111111111111');
    });

    test('rejects blank and non-UUID identity values', () {
      expect(() => LocalUserScope(''), throwsArgumentError);
      expect(() => LocalUserScope('staff@example.com'), throwsArgumentError);
      expect(() => LocalUserScope('user-current'), throwsArgumentError);
    });

    test('compares scopes by owner user ID', () {
      final first = LocalUserScope('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
      final second = LocalUserScope('aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa');
      final other = LocalUserScope('bbbbbbbb-bbbb-4bbb-8bbb-bbbbbbbbbbbb');

      expect(first, second);
      expect(first.hashCode, second.hashCode);
      expect(first, isNot(other));
    });
  });
}
