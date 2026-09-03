import 'dart:io';

bool isPlatformStaffDirectoryConnectivityFailure(Object error) =>
    error is SocketException;
