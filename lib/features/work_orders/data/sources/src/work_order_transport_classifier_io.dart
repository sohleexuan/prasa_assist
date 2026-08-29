import 'dart:io';

bool isPlatformConnectivityFailure(Object error) => error is SocketException;
