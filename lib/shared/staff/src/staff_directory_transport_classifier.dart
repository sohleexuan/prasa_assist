import 'staff_directory_transport_classifier_stub.dart'
    if (dart.library.io) 'staff_directory_transport_classifier_io.dart'
    as platform;

bool isStaffDirectoryConnectivityFailure(Object error) =>
    platform.isPlatformStaffDirectoryConnectivityFailure(error);
