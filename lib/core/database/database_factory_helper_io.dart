import 'dart:io';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

DatabaseFactory initDatabaseFactory() {
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    return databaseFactoryFfi;
  }
  return databaseFactory;
}
