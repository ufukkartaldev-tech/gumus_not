import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:connected_notebook/core/database/sqlite_database_service.dart';
import 'package:connected_notebook/core/database/database_factory_helper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  group('SqliteDatabaseService Multiplatform Tests', () {
    test('setupDatabaseFactory should return valid DatabaseFactory instance', () {
      final factory = setupDatabaseFactory();
      expect(factory, isNotNull);
    });

    test('SqliteDatabaseService should open database and perform CRUD operations', () async {
      final dbService = SqliteDatabaseService();
      final db = await dbService.database;
      expect(db.isOpen, isTrue);

      // 1. Insert
      final now = DateTime.now().millisecondsSinceEpoch;
      final id = await dbService.insertNote({
        'title': 'Kalıcı Not Başlığı',
        'content': 'Kalıcı SQLite içeriği',
        'created_at': now,
        'updated_at': now,
        'folder_name': 'Genel',
      });
      expect(id, isPositive);

      // 2. Query
      final retrieved = await dbService.getNoteById(id);
      expect(retrieved, isNotNull);
      expect(retrieved!.first['title'], 'Kalıcı Not Başlığı');

      // 3. Update
      final updated = await dbService.updateNote({
        'id': id,
        'title': 'Güncellenmiş Başlık',
        'content': 'Güncellenmiş içerik',
        'created_at': now,
        'updated_at': DateTime.now().millisecondsSinceEpoch,
        'folder_name': 'Genel',
      });
      expect(updated, 1);

      // 4. Delete
      final deleted = await dbService.deleteNote(id);
      expect(deleted, 1);

      final afterDelete = await dbService.getNoteById(id);
      expect(afterDelete == null || afterDelete.isEmpty, isTrue);
    });
  });
}
