import 'dart:io';

bool isIncidentTransportFailure(Object error) => error is SocketException;
