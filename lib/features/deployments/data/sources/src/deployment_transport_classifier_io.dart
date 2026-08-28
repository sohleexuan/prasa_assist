import 'dart:io';

bool isDeploymentTransportFailure(Object error) => error is SocketException;
