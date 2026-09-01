import 'package:prasa_assist/core/database/app_database.dart';
import 'package:prasa_assist/core/database/app_database_opener.dart';
import 'package:prasa_assist/core/database/app_database_schema.dart';
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

Future<Database> createVersionOneFileDatabase(String path) {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: AppDatabaseSchema.onConfigure,
      onCreate: AppDatabaseSchema.onCreate,
      singleInstance: false,
    ),
  );
}

Future<Database> createVersionTwoFileDatabase(String path) {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 2,
      onConfigure: AppDatabaseSchema.onConfigure,
      onCreate: AppDatabaseSchema.onCreate,
      singleInstance: false,
    ),
  );
}

Future<Database> createVersionThreeFileDatabase(String path) {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 3,
      onConfigure: AppDatabaseSchema.onConfigure,
      onCreate: AppDatabaseSchema.onCreate,
      singleInstance: false,
    ),
  );
}

Future<Database> createVersionFourFileDatabase(String path) {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 4,
      onConfigure: AppDatabaseSchema.onConfigure,
      onCreate: AppDatabaseSchema.onCreate,
      singleInstance: false,
    ),
  );
}

Future<Database> createVersionFiveFileDatabase(String path) {
  sqfliteFfiInit();
  return databaseFactoryFfi.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 5,
      onConfigure: AppDatabaseSchema.onConfigure,
      onCreate: AppDatabaseSchema.onCreate,
      singleInstance: false,
    ),
  );
}
