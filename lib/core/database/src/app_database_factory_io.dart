import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart' as ffi;

DatabaseFactory resolveDatabaseFactory() {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS => databaseFactory,
    TargetPlatform.windows || TargetPlatform.linux => _ffiDatabaseFactory(),
    TargetPlatform.fuchsia => unsupportedDatabaseFactory(),
  };
}

DatabaseFactory _ffiDatabaseFactory() {
  ffi.sqfliteFfiInit();
  return ffi.databaseFactoryFfi;
}

Never unsupportedDatabaseFactory() {
  throw UnsupportedError(
    'Local SQLite storage is not supported on this platform.',
  );
}
