import 'package:prasa_assist/core/database/app_database.dart';
import 'package:prasa_assist/core/database/app_database_opener.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

AppDatabase createInMemoryTestDatabase() {
  sqfliteFfiInit();
  return AppDatabase(
    opener: AppDatabaseOpener(
      databaseFactory: databaseFactoryFfi,
      databasePath: inMemoryDatabasePath,
      singleInstance: false,
    ),
  );
}

AppDatabase createFileTestDatabase(String path) {
  sqfliteFfiInit();
  return AppDatabase(
    opener: AppDatabaseOpener(
      databaseFactory: databaseFactoryFfi,
      databasePath: path,
      singleInstance: false,
    ),
  );
}
