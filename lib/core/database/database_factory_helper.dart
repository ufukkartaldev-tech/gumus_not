import 'package:sqflite/sqflite.dart';

import 'database_factory_helper_stub.dart'
    if (dart.library.html) 'database_factory_helper_web.dart'
    if (dart.library.io) 'database_factory_helper_io.dart';

/// Initializes the appropriate SQLite database factory based on runtime platform:
/// - Web: `databaseFactoryFfiWeb` (IndexedDB persistence)
/// - Desktop (Windows, Linux, macOS): `databaseFactoryFfi` (`sqflite_common_ffi`)
/// - Mobile (Android, iOS): Standard platform sqflite
DatabaseFactory setupDatabaseFactory() {
  return initDatabaseFactory();
}
