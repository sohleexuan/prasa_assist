import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:prasa_assist/features/work_orders/data/sources/src/work_order_transport_classifier.dart';
import 'package:prasa_assist/features/work_orders/repositories/work_order_data_exception.dart';

void main() {
  test('only verified read connectivity failures allow fallback', () {
    expect(
      isVerifiedWorkOrderReadTransportFailure(TimeoutException('timeout')),
      isTrue,
    );
    expect(
      isVerifiedWorkOrderReadTransportFailure(
        const WorkOrderOfflineException('Offline.'),
      ),
      isTrue,
    );
    for (final error in <Object>[
      const WorkOrderPermissionException('Denied.'),
      const WorkOrderValidationException('Invalid.'),
      const WorkOrderConflictException('Conflict.'),
      const WorkOrderMappingException('Malformed.'),
      const WorkOrderCorruptionException('Corrupt.'),
      const WorkOrderUnknownDataException('Unknown.'),
    ]) {
      expect(isVerifiedWorkOrderReadTransportFailure(error), isFalse);
    }
  });
}
