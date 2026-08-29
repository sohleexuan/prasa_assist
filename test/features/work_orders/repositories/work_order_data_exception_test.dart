import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/work_orders/repositories/work_order_data_exception.dart';

void main() {
  test('typed exception exposes only safe message through toString', () {
    final error = WorkOrderLocalStorageException(
      'Local work-order data is unavailable.',
      cause: StateError('raw SQL detail'),
    );
    expect(error.cause, isA<StateError>());
    expect(error.toString(), 'Local work-order data is unavailable.');
    expect(error.toString(), isNot(contains('raw SQL')));
  });
}
