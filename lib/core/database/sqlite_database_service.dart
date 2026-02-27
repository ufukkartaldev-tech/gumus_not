import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'idatabase_service.dart';

/// Concrete implementation of IDatabaseService using SQLite
/// Follows Single Responsibility Principle: Only handles SQLite operations
class SqliteDatabaseService implements IDatabaseService {
  static Database? _database;
  static const String _dbName = 'connected_notebook.db';
  static const int _dbVersion = 3;

  @override
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _dbName);
    
    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE notes (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        content TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL,
        is_encrypted INTEGER DEFAULT 0,
        tags TEXT,
        color INTEGER,
        folder_name TEXT DEFAULT 'Genel'
      )
    ''');

    await db.execute('''
      CREATE TABLE backlinks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        source_note_id INTEGER NOT NULL,
        target_note_id INTEGER NOT NULL,
        link_text TEXT NOT NULL,
        created_at INTEGER NOT NULL,
        FOREIGN KEY (source_note_id) REFERENCES notes (id) ON DELETE CASCADE,
        FOREIGN KEY (target_note_id) REFERENCES notes (id) ON DELETE CASCADE
      )
    ''');

    await db.execute('''
      CREATE TABLE templates (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        content TEXT NOT NULL,
        category TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');

    await db.execute('''
      CREATE INDEX idx_notes_title ON notes(title);
      CREATE INDEX idx_notes_created_at ON notes(created_at);
      CREATE INDEX idx_backlinks_source ON backlinks(source_note_id);
      CREATE INDEX idx_backlinks_target ON backlinks(target_note_id);
    ''');
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE notes ADD COLUMN color INTEGER');
    }
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE notes ADD COLUMN folder_name TEXT DEFAULT 'Genel'");
    }
  }

  @override
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }

  // Note operations
  @override
  Future<int> insertNote(Map<String, dynamic> note) async {
    final db = await database;
    return await db.insert('notes', note);
  }

  @override
  Future<List<Map<String, dynamic>>> getAllNotes() async {
    final db = await database;
    return await db.query('notes', orderBy: 'updated_at DESC');
  }

  @override
  Future<List<Map<String, dynamic>>?> getNoteById(int id) async {
    final db = await database;
    final maps = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty ? maps : null;
  }

  @override
  Future<int> updateNote(Map<String, dynamic> note) async {
    final db = await database;
    note['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    return await db.update(
      'notes',
      note,
      where: 'id = ?',
      whereArgs: [note['id']],
    );
  }

  @override
  Future<int> deleteNote(int id) async {
    final db = await database;
    return await db.delete('notes', where: 'id = ?', whereArgs: [id]);
  }

  @override
  Future<List<Map<String, dynamic>>> searchNotes(String query) async {
    final db = await database;
    return await db.query(
      'notes',
      where: 'title LIKE ? OR content LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'updated_at DESC',
    );
  }

  // Backlink operations
  @override
  Future<void> insertBacklink(Map<String, dynamic> backlink) async {
    final db = await database;
    await db.insert('backlinks', backlink);
  }

  @override
  Future<List<Map<String, dynamic>>> getBacklinksForNote(int noteId) async {
    final db = await database;
    return await db.query(
      'backlinks',
      where: 'target_note_id = ?',
      whereArgs: [noteId],
      orderBy: 'created_at DESC',
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getOutgoingLinksForNote(int noteId) async {
    final db = await database;
    return await db.query(
      'backlinks',
      where: 'source_note_id = ?',
      whereArgs: [noteId],
      orderBy: 'created_at DESC',
    );
  }

  @override
  Future<void> updateBacklinks(int? noteId, String content, List<Map<String, dynamic>> allNotes) async {
    final db = await database;
    
    await db.delete(
      'backlinks',
      where: 'source_note_id = ?',
      whereArgs: [noteId],
    );

    final RegExp linkRegex = RegExp(r'\[\[([^\]]+)\]\]');
    final matches = linkRegex.allMatches(content);
    
    for (final match in matches) {
      final linkText = match.group(1)!;
      
      final targetNote = allNotes.firstWhere(
        (note) => note['title'].toString().toLowerCase() == linkText.toLowerCase(),
        orElse: () => {
          'id': -1,
          'title': linkText,
          'content': '',
          'created_at': DateTime.now().millisecondsSinceEpoch,
          'updated_at': DateTime.now().millisecondsSinceEpoch,
        },
      );

      if (targetNote['id'] != -1) {
        final backlink = {
          'source_note_id': noteId,
          'target_note_id': targetNote['id'],
          'link_text': linkText,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        };
        await db.insert('backlinks', backlink);
      }
    }
  }

  // Template operations
  @override
  Future<int> insertTemplate(Map<String, dynamic> template) async {
    final db = await database;
    return await db.insert('templates', template);
  }

  @override
  Future<List<Map<String, dynamic>>> getAllTemplates() async {
    final db = await database;
    return await db.query('templates', orderBy: 'created_at DESC');
  }

  @override
  Future<int> updateTemplate(Map<String, dynamic> template) async {
    final db = await database;
    return await db.update(
      'templates',
      template,
      where: 'id = ?',
      whereArgs: [template['id']],
    );
  }

  @override
  Future<int> deleteTemplate(int id) async {
    final db = await database;
    return await db.delete('templates', where: 'id = ?', whereArgs: [id]);
  }

  // Query operations
  @override
  Future<List<Map<String, dynamic>>> getRecentNotes({int limit = 5}) async {
    final db = await database;
    return await db.query(
      'notes',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingTasks({int limit = 10}) async {
    final db = await database;
    return await db.query(
      'notes',
      where: 'content LIKE ?',
      whereArgs: ['% - [ %'],
      orderBy: 'updated_at DESC',
      limit: limit,
    );
  }

  @override
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final db = await database;
    
    final totalNotesResult = await db.rawQuery('SELECT COUNT(*) as count FROM notes');
    final totalTasksResult = await db.rawQuery('SELECT COUNT(*) as count FROM notes WHERE content LIKE "% - [ %"');
    final lastNoteResult = await db.query('notes', orderBy: 'updated_at DESC', limit: 1);
    
    return {
      'totalNotes': totalNotesResult.first['count'],
      'totalTasks': totalTasksResult.first['count'],
      'lastNoteDate': lastNoteResult.isNotEmpty ? lastNoteResult.first['updated_at'] : null,
    };
  }

  // Batch operations
  @override
  Future<void> insertNotes(List<Map<String, dynamic>> notes) async {
    final db = await database;
    final batch = db.batch();
    
    for (final note in notes) {
      batch.insert('notes', note);
    }
    
    await batch.commit();
  }

  @override
  Future<void> deleteNotes(List<int> noteIds) async {
    final db = await database;
    final batch = db.batch();
    
    for (final id in noteIds) {
      batch.delete('notes', where: 'id = ?', whereArgs: [id]);
    }
    
    await batch.commit();
  }

  // Database management
  @override
  Future<void> backup(String path) async {
    final db = await database;
    // In a real implementation, this would copy the database file
    // For now, we'll just log the operation
    print('Backup database to: $path');
  }

  @override
  Future<void> restore(String path) async {
    // In a real implementation, this would restore from backup
    print('Restore database from: $path');
  }

  @override
  Future<void> vacuum() async {
    final db = await database;
    await db.execute('VACUUM');
  }

  @override
  Future<void> optimize() async {
    final db = await database;
    await db.execute('ANALYZE');
    await db.execute('REINDEX');
  }
}
