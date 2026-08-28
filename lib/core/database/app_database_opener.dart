import 'package:sqflite/sqflite.dart';

import 'app_database_schema.dart';
import 'src/app_database_factory_stub.dart'
    if (dart.library.io) 'src/app_database_factory_io.dart'
    as platform;

typedef AppDatabaseFactoryResolver = DatabaseFactory Function();

class AppDatabaseOpener {
  AppDatabaseOpener({
    DatabaseFactory? databaseFactory,
    this.databasePath,
    this.singleInstance = true,
  }) : _factoryResolver = databaseFactory == null
           ? platform.resolveDatabaseFactory
           : _fixedDatabaseFactory(databaseFactory);

  AppDatabaseOpener.unsupported({this.databasePath, this.singleInstance = true})
    : _factoryResolver = platform.unsupportedDatabaseFactory;

  final AppDatabaseFactoryResolver _factoryResolver;
  final String? databasePath;
  final bool singleInstance;

  Future<Database> open() async {
    final factory = _factoryResolver();
    final path = databasePath ?? await _defaultDatabasePath(factory);
    return factory.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: AppDatabaseSchema.version,
        onConfigure: AppDatabaseSchema.onConfigure,
        onCreate: AppDatabaseSchema.onCreate,
        onUpgrade: AppDatabaseSchema.onUpgrade,
        singleInstance: singleInstance,
      ),
    );
  }

  Future<String> _defaultDatabasePath(DatabaseFactory factory) async {
    final basePath = await factory.getDatabasesPath();
    final separator = basePath.endsWith('/') || basePath.endsWith('\\')
        ? ''
        : '/';
    return '$basePath$separator${AppDatabaseSchema.filename}';
  }
}

AppDatabaseFactoryResolver _fixedDatabaseFactory(DatabaseFactory factory) {
  return () => factory;
}
