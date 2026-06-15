import 'package:sqflite/sqflite.dart';

import 'idatabase_service.dart';
import 'secure_database_service.dart';

/// Bridges the legacy [IDatabaseService] contract to the new
/// [ISecureDatabaseService] implementation so existing repository and UI code
/// can migrate incrementally without breaking.
class LegacyDatabaseServiceAdapter implements IDatabaseService {
  LegacyDatabaseServiceAdapter(this._secureDatabaseService);

  final ISecureDatabaseService _secureDatabaseService;

  @override
  Future<Database> get database => _secureDatabaseService.open();

  @override
  Future<void> close() => _secureDatabaseService.close();

  @override
  Future<int> insertNote(Map<String, dynamic> note) {
    return _secureDatabaseService.insertNote(note);
  }

  @override
  Future<List<Map<String, dynamic>>> getAllNotes() {
    return _secureDatabaseService.getAllNotes();
  }

  @override
  Future<List<Map<String, dynamic>>?> getNoteById(int id) {
    return _secureDatabaseService.getNoteById(id);
  }

  @override
  Future<int> updateNote(Map<String, dynamic> note) {
    return _secureDatabaseService.updateNote(note);
  }

  @override
  Future<int> deleteNote(int id) {
    return _secureDatabaseService.deleteNote(id);
  }

  @override
  Future<List<Map<String, dynamic>>> searchNotes(String query) {
    return _secureDatabaseService.searchNotes(query);
  }

  @override
  Future<void> insertBacklink(Map<String, dynamic> backlink) async {
    throw UnimplementedError(
      'Use updateBacklinks/replaceBacklinks transaction flow through SecureSqliteDatabaseService.',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getBacklinksForNote(int noteId) async {
    final db = await _secureDatabaseService.open();
    return db.transaction(
      (txn) => txn.query(
        'backlinks',
        where: 'target_note_id = ?',
        whereArgs: [noteId],
        orderBy: 'created_at DESC',
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getOutgoingLinksForNote(int noteId) async {
    final db = await _secureDatabaseService.open();
    return db.transaction(
      (txn) => txn.query(
        'backlinks',
        where: 'source_note_id = ?',
        whereArgs: [noteId],
        orderBy: 'created_at DESC',
      ),
    );
  }

  @override
  Future<void> updateBacklinks(
    int? noteId,
    String content,
    List<Map<String, dynamic>> allNotes,
  ) async {
    if (noteId == null) return;
    await _secureDatabaseService.replaceBacklinks(
      noteId: noteId,
      content: content,
      allNotes: allNotes,
    );
  }

  @override
  Future<int> insertTemplate(Map<String, dynamic> template) {
    return _secureDatabaseService.insertTemplate(template);
  }

  @override
  Future<List<Map<String, dynamic>>> getAllTemplates() {
    return _secureDatabaseService.getAllTemplates();
  }

  @override
  Future<int> updateTemplate(Map<String, dynamic> template) {
    return _secureDatabaseService.updateTemplate(template);
  }

  @override
  Future<int> deleteTemplate(int id) {
    return _secureDatabaseService.deleteTemplate(id);
  }

  @override
  Future<List<Map<String, dynamic>>> getRecentNotes({int limit = 5}) async {
    final db = await _secureDatabaseService.open();
    return db.transaction(
      (txn) => txn.query(
        'notes',
        orderBy: 'updated_at DESC',
        limit: limit,
      ),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingTasks({int limit = 10}) async {
    final db = await _secureDatabaseService.open();
    return db.transaction(
      (txn) => txn.query(
        'notes',
        where: r'content LIKE ? ESCAPE "\\"',
        whereArgs: ['% - [ %'],
        orderBy: 'updated_at DESC',
        limit: limit,
      ),
    );
  }

  @override
  Future<int> getNoteCountInFolder(String folderName) async {
    final db = await _secureDatabaseService.open();
    return db.transaction((txn) async {
      final result = await txn.rawQuery(
        'SELECT COUNT(*) as count FROM notes WHERE folder_name = ?',
        [folderName],
      );

      return result.first['count'] as int;
    });
  }

  @override
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final db = await _secureDatabaseService.open();
    return db.transaction((txn) async {
      final totalNotes = await txn.rawQuery('SELECT COUNT(*) as count FROM notes');
      final encryptedNotes = await txn.rawQuery(
        'SELECT COUNT(*) as count FROM notes WHERE is_encrypted = 1',
      );
      final templates = await txn.rawQuery('SELECT COUNT(*) as count FROM templates');

      return {
        'totalNotes': totalNotes.first['count'] ?? 0,
        'encryptedNotes': encryptedNotes.first['count'] ?? 0,
        'templates': templates.first['count'] ?? 0,
      };
    });
  }

  @override
  Future<void> insertNotes(List<Map<String, dynamic>> notes) async {
    final db = await _secureDatabaseService.open();
    await db.transaction((txn) async {
      for (final note in notes) {
        final id = await txn.insert('notes', note);
        await txn.insert('notes_fts', {
          'id': id,
          'title': note['title'],
          'content': note['content'],
        });
      }
    });
  }

  @override
  Future<void> deleteNotes(List<int> noteIds) async {
    final db = await _secureDatabaseService.open();
    await db.transaction((txn) async {
      for (final noteId in noteIds) {
        await txn.delete('notes_fts', where: 'id = ?', whereArgs: [noteId]);
        await txn.delete('notes', where: 'id = ?', whereArgs: [noteId]);
      }
    });
  }

  @override
  Future<void> backup(String path) async {
    throw UnimplementedError('Backup flow should be handled by a dedicated backup service.');
  }

  @override
  Future<void> restore(String path) async {
    throw UnimplementedError('Restore flow should be handled by a dedicated backup service.');
  }

  @override
  Future<void> vacuum() async {
    final db = await _secureDatabaseService.open();
    await db.execute('VACUUM');
  }

  @override
  Future<void> optimize() async {
    final db = await _secureDatabaseService.open();
    await db.transaction((txn) async {
      await txn.execute('ANALYZE');
      await txn.execute('REINDEX');
    });
  }
}
