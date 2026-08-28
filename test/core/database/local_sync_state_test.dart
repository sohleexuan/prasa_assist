import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/core/database/local_sync_state.dart';

void main() {
  test('local sync states have stable unique storage values', () {
    final storageValues = LocalSyncState.values
        .map((state) => state.storageValue)
        .toSet();

    expect(storageValues, hasLength(LocalSyncState.values.length));
    for (final state in LocalSyncState.values) {
      expect(LocalSyncState.fromStorage(state.storageValue), state);
    }
    expect(storageValues, isNot(contains('synced')));
  });

  test('unknown stored sync states fail safely', () {
    expect(
      () => LocalSyncState.fromStorage('silently_synced'),
      throwsFormatException,
    );
  });
}
