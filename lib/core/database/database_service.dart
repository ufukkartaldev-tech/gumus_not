import 'dart:math';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';

class DatabaseService {
  static Database? _database;
  static const String _dbName = 'connected_notebook.db';
  static const int _dbVersion = 3;

  static Future<Database> get database async {
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

    await db.execute('''
      CREATE INDEX idx_notes_title ON notes(title);
      CREATE INDEX idx_notes_created_at ON notes(created_at);
      CREATE INDEX idx_backlinks_source ON backlinks(source_note_id);
      CREATE INDEX idx_backlinks_target ON backlinks(target_note_id);
    ''');
  }

  static Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE notes ADD COLUMN color INTEGER');
    }
    if (oldVersion < 3) {
      await db.execute("ALTER TABLE notes ADD COLUMN folder_name TEXT DEFAULT 'Genel'");
    }
  }

  static Future<int> insertNote(Note note) async {
    final db = await database;
    return await db.insert('notes', note.toMap());
  }

  static Future<List<Note>> getAllNotes() async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      orderBy: 'updated_at DESC',
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  static Future<Note?> getNoteById(int id) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (maps.isNotEmpty) {
      return Note.fromMap(maps.first);
    }
    return null;
  }

  static Future<List<Note>> searchNotes(String query) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'title LIKE ? OR content LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'updated_at DESC',
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  static Future<int> updateNote(Note note) async {
    final db = await database;
    note.updatedAt = DateTime.now().millisecondsSinceEpoch;
    return await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  static Future<int> deleteNote(int id) async {
    final db = await database;
    return await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  static Future<void> insertBacklink(Backlink backlink) async {
    final db = await database;
    await db.insert('backlinks', backlink.toMap());
  }

  static Future<List<Backlink>> getBacklinksForNote(int noteId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'backlinks',
      where: 'target_note_id = ?',
      whereArgs: [noteId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Backlink.fromMap(maps[i]));
  }

  static Future<List<Backlink>> getOutgoingLinksForNote(int noteId) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'backlinks',
      where: 'source_note_id = ?',
      whereArgs: [noteId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Backlink.fromMap(maps[i]));
  }

  static Future<void> updateBacklinks(int? noteId, String content, List<Note> allNotes) async {
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
        (note) => note.title.toLowerCase() == linkText.toLowerCase(),
        orElse: () => Note(
          id: -1,
          title: linkText,
          content: '',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      if (targetNote.id != -1) {
        final backlink = Backlink(
          sourceNoteId: noteId!,
          targetNoteId: targetNote.id!,
          linkText: linkText,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
        await db.insert('backlinks', backlink.toMap());
      }
    }
  }

  static Future<List<Note>> getRecentNotes({int limit = 5}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  static Future<List<Note>> getPendingTasks({int limit = 10}) async {
    final db = await database;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'content LIKE ?',
      whereArgs: ['% - [ %'],
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  static Future<Map<String, dynamic>> getDatabaseStats() async {
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

  static Future<void> close() async {
    final db = await database;
    await db.close();
    _database = null;
  }
}
