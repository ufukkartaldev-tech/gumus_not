import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// Abstract interface for database operations
/// Follows Dependency Inversion Principle
abstract class IDatabaseService {
  Future<Database> get database;
  Future<void> close();

  // Note operations
  Future<int> insertNote(Map<String, dynamic> note);
  Future<List<Map<String, dynamic>>> getAllNotes();
  Future<List<Map<String, dynamic>>?> getNoteById(int id);
  Future<int> updateNote(Map<String, dynamic> note);
  Future<int> deleteNote(int id);
  Future<List<Map<String, dynamic>>> searchNotes(String query);

  // Backlink operations
  Future<void> insertBacklink(Map<String, dynamic> backlink);
  Future<List<Map<String, dynamic>>> getBacklinksForNote(int noteId);
  Future<List<Map<String, dynamic>>> getOutgoingLinksForNote(int noteId);
  Future<void> updateBacklinks(
    int? noteId,
    String content,
    List<Map<String, dynamic>> allNotes,
  );

  // Template operations
  Future<int> insertTemplate(Map<String, dynamic> template);
  Future<List<Map<String, dynamic>>> getAllTemplates();

  // Query operations
  Future<List<Map<String, dynamic>>> getRecentNotes({int limit = 5});
  Future<List<Map<String, dynamic>>> getPendingTasks({int limit = 10});
  Future<int> getNoteCountInFolder(String folderName);
}

/// Concrete implementation using SQLite
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

  static Future<Database> _initDatabase() async {
    String path = join(await getDatabasesPath(), _dbName);

    return await openDatabase(
      path,
      version: _dbVersion,
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  static Future<void> _onCreate(Database db, int version) async {
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

    await db.execute('CREATE INDEX idx_notes_title ON notes(title)');
    await db.execute('CREATE INDEX idx_notes_created_at ON notes(created_at)');
    await db.execute(
      'CREATE INDEX idx_backlinks_source ON backlinks(source_note_id)',
    );
    await db.execute(
      'CREATE INDEX idx_backlinks_target ON backlinks(target_note_id)',
    );
  }

  static Future<void> _onUpgrade(
    Database db,
    int oldVersion,
    int newVersion,
  ) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE notes ADD COLUMN color INTEGER');
    }
    if (oldVersion < 3) {
      await db.execute(
        "ALTER TABLE notes ADD COLUMN folder_name TEXT DEFAULT 'Genel'",
      );
    }
  }

  @override
  Future<int> insertNote(Map<String, dynamic> note) async {
    final db = await database;
    return await db.insert('notes', note);
  }

  @override
  Future<List<Map<String, dynamic>>> getAllNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      orderBy: 'updated_at DESC',
    );
    return maps;
  }

  @override
  Future<List<Map<String, dynamic>>?> getNoteById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    return maps.isNotEmpty ? maps : null;
  }

  @override
  Future<List<Map<String, dynamic>>> searchNotes(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'title LIKE ? OR content LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'updated_at DESC',
    );
    return maps;
  }

  @override
  Future<int> updateNote(Map<String, dynamic> note) async {
    final db = await database;
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
  Future<void> insertBacklink(Map<String, dynamic> backlink) async {
    final db = await database;
    await db.insert('backlinks', backlink);
  }

  @override
  Future<List<Map<String, dynamic>>> getBacklinksForNote(int noteId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'backlinks',
      where: 'target_note_id = ?',
      whereArgs: [noteId],
      orderBy: 'created_at DESC',
    );
    return maps;
  }

  @override
  Future<List<Map<String, dynamic>>> getOutgoingLinksForNote(int noteId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'backlinks',
      where: 'source_note_id = ?',
      whereArgs: [noteId],
      orderBy: 'created_at DESC',
    );
    return maps;
  }

  @override
  Future<void> updateBacklinks(
    int? noteId,
    String content,
    List<Map<String, dynamic>> allNotes,
  ) async {
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
        (note) =>
            note['title'].toString().toLowerCase() == linkText.toLowerCase(),
        orElse: () => {'id': -1},
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

  @override
  Future<int> insertTemplate(Map<String, dynamic> template) async {
    final db = await database;
    return await db.insert('templates', template);
  }

  @override
  Future<List<Map<String, dynamic>>> getAllTemplates() async {
    final db = await database;
    return await db.query('templates');
  }

  @override
  Future<List<Map<String, dynamic>>> getRecentNotes({int limit = 5}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return maps;
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingTasks({int limit = 10}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'content LIKE ?',
      whereArgs: ['% - [ %'],
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return maps;
  }

  @override
  Future<int> getNoteCountInFolder(String folderName) async {
    final db = await database;

    final result = await db.rawQuery(
      'SELECT COUNT(*) as count FROM notes WHERE folder_name = ?',
      [folderName],
    );

    return result.first['count'] as int;
  }

  @override
  Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
