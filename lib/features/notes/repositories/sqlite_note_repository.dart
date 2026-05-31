import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/repositories/note_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// SQLite implementation of NoteRepository
/// Follows Single Responsibility Principle: Only handles SQLite operations
class SqliteNoteRepository implements NoteRepository {
  Database? _database;
  static const String _dbName = 'connected_notebook.db';
  static const int _dbVersion = 3;

  Future<Database> get _db async {
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
  Future<List<Note>> getAllNotes() async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      orderBy: 'updated_at DESC',
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  @override
  Future<Note?> getNoteById(int id) async {
    final db = await _db;
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

  @override
  Future<List<Note>> searchNotes(String query) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'title LIKE ? OR content LIKE ?',
      whereArgs: ['%$query%', '%$query%'],
      orderBy: 'updated_at DESC',
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  @override
  Future<int> addNote(Note note) async {
    final db = await _db;
    return await db.insert('notes', note.toMap());
  }

  @override
  Future<void> updateNote(Note note) async {
    final db = await _db;
    note.updatedAt = DateTime.now().millisecondsSinceEpoch;
    await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
  }

  @override
  Future<void> deleteNote(int id) async {
    final db = await _db;
    await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  @override
  Future<List<Note>> getRecentNotes({int limit = 5}) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  @override
  Future<List<Note>> getPendingTasks({int limit = 10}) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'content LIKE ?',
      whereArgs: ['% - [ %'],
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }

  @override
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final db = await _db;
    
    final totalNotesResult = await db.rawQuery('SELECT COUNT(*) as count FROM notes');
    final totalTasksResult = await db.rawQuery('SELECT COUNT(*) as count FROM notes WHERE content LIKE "% - [ %"');
    final lastNoteResult = await db.query('notes', orderBy: 'updated_at DESC', limit: 1);
    
    return {
      'totalNotes': totalNotesResult.first['count'],
      'totalTasks': totalTasksResult.first['count'],
      'lastNoteDate': lastNoteResult.isNotEmpty ? lastNoteResult.first['updated_at'] : null,
    };
  }

  @override
  Future<List<Backlink>> getBacklinksForNote(int noteId) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'backlinks',
      where: 'target_note_id = ?',
      whereArgs: [noteId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Backlink.fromMap(maps[i]));
  }

  @override
  Future<List<Backlink>> getOutgoingLinksForNote(int noteId) async {
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'backlinks',
      where: 'source_note_id = ?',
      whereArgs: [noteId],
      orderBy: 'created_at DESC',
    );
    return List.generate(maps.length, (i) => Backlink.fromMap(maps[i]));
  }

  @override
  Future<void> updateBacklinks(Note note, List<Note> allNotes) async {
    final db = await _db;
    
    // Delete existing backlinks from this note
    await db.delete(
      'backlinks',
      where: 'source_note_id = ?',
      whereArgs: [note.id],
    );

    // Extract links from content
    final RegExp linkRegex = RegExp(r'\[\[([^\]]+)\]\]');
    final matches = linkRegex.allMatches(note.content);
    
    for (final match in matches) {
      final linkText = match.group(1)!;
      
      // Find target note
      final targetNote = allNotes.firstWhere(
        (n) => n.title.toLowerCase() == linkText.toLowerCase(),
        orElse: () => Note(
          id: -1,
          title: linkText,
          content: '',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );

      // Only create backlink if target note exists
      if (targetNote.id != -1) {
        final backlink = Backlink(
          sourceNoteId: note.id!,
          targetNoteId: targetNote.id!,
          linkText: linkText,
          createdAt: DateTime.now().millisecondsSinceEpoch,
        );
        await db.insert('backlinks', backlink.toMap());
      }
    }
  }

  @override
  Future<List<String>> getFolders() async {
    final notes = await getAllNotes();
    final folderSet = notes.map((n) => n.folderName).where((f) => f.isNotEmpty).toSet();
    if (!folderSet.contains('Genel')) folderSet.add('Genel');
    final list = folderSet.toList()..sort();
    return list;
  }

  @override
  Future<int> getNoteCountInFolder(String folderName) async {
    final notes = await getAllNotes();
    return notes.where((n) => n.folderName == folderName).length;
  }

  @override
  Future<List<Note>> getNotesByTag(String tag) async {
    final notes = await getAllNotes();
    return notes.where((note) => note.tags.contains(tag)).toList();
  }

  @override
  Future<Map<String, int>> getTagFrequency() async {
    final notes = await getAllNotes();
    final Map<String, int> tagFrequency = {};
    for (final note in notes) {
      for (final tag in note.tags) {
        tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
      }
    }
    return tagFrequency;
  }

  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}