import 'dart:async';

import '../../../repositories/work_order_data_exception.dart';
import 'work_order_transport_classifier_stub.dart'
    if (dart.library.io) 'work_order_transport_classifier_io.dart'
    as platform;

bool isVerifiedWorkOrderReadTransportFailure(Object error) {
  return error is WorkOrderOfflineException ||
      error is TimeoutException ||
      platform.isPlatformConnectivityFailure(error);
}
