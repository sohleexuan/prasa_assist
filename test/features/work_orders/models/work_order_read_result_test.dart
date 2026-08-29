import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/work_orders/models/work_order_read_result.dart';

void main() {
  test('provenance distinguishes live and cached UTC retrievals', () {
    final cached = WorkOrderReadProvenance(
      source: WorkOrderReadSource.cachedSqlite,
      retrievedAtUtc: DateTime.parse('2026-08-29T10:00:00+08:00'),
      warningMessage: 'Showing cached SQLite data.',
    );
    final result = WorkOrderReadResult(
      data: const ['WO-1'],
      provenance: cached,
    );
    expect(result.provenance.isCached, isTrue);
    expect(result.provenance.retrievedAtUtc.isUtc, isTrue);
    expect(result.data, ['WO-1']);
  });
}
