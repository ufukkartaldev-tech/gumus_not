import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

abstract class ISecureDatabaseService {
  Future<Database> open();
  Future<void> close();

  Future<int> insertNote(Map<String, dynamic> note);
  Future<List<Map<String, dynamic>>> getAllNotes();
  Future<List<Map<String, dynamic>>> searchNotes(String query);
  Future<List<Map<String, dynamic>>?> getNoteById(int id);
  Future<int> updateNote(Map<String, dynamic> note);
  Future<int> deleteNote(int id);

  Future<void> replaceBacklinks({
    required int noteId,
    required String content,
    required List<Map<String, dynamic>> allNotes,
  });

  Future<int> insertTemplate(Map<String, dynamic> template);
  Future<int> updateTemplate(Map<String, dynamic> template);
  Future<int> deleteTemplate(int id);
  Future<List<Map<String, dynamic>>> getAllTemplates();
}

class SecureSqliteDatabaseService implements ISecureDatabaseService {
  SecureSqliteDatabaseService({
    String dbName = 'connected_notebook.db',
    int dbVersion = 5,
  })  : _dbName = dbName,
        _dbVersion = dbVersion;

  final String _dbName;
  final int _dbVersion;

  Database? _database;
  Future<Database>? _openingFuture;

  @override
  Future<Database> open() async {
    final existing = _database;
    if (existing != null) return existing;

    final inFlight = _openingFuture;
    if (inFlight != null) return inFlight;

    _openingFuture = _openInternal();
    final db = await _openingFuture!;
    _database = db;
    _openingFuture = null;
    return db;
  }

  Future<Database> _openInternal() async {
    final path = join(await getDatabasesPath(), _dbName);

    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) async {
        await db.execute('PRAGMA foreign_keys = ON');
      },
      onCreate: _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  Future<void> _onCreate(Database db, int version) async {
    await db.transaction((txn) async {
      await txn.execute('''
        CREATE TABLE notes (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          title TEXT NOT NULL,
          content TEXT NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          is_encrypted INTEGER NOT NULL DEFAULT 0,
          tags TEXT,
          color INTEGER,
          folder_name TEXT NOT NULL DEFAULT 'Genel'
        )
      ''');

      await txn.execute('''
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

      await txn.execute('''
        CREATE TABLE templates (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          name TEXT NOT NULL,
          content TEXT NOT NULL,
          category TEXT NOT NULL,
          created_at INTEGER NOT NULL
        )
      ''');

      await txn.execute('CREATE INDEX idx_notes_title ON notes(title)');
      await txn.execute('CREATE INDEX idx_notes_updated_at ON notes(updated_at)');
      await txn.execute('CREATE INDEX idx_backlinks_source ON backlinks(source_note_id)');
      await txn.execute('CREATE INDEX idx_backlinks_target ON backlinks(target_note_id)');

      await txn.execute('''
        CREATE VIRTUAL TABLE notes_fts USING fts5(
          id UNINDEXED,
          title,
          content
        )
      ''');
    });
  }

  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    await db.transaction((txn) async {
      if (oldVersion < 2) {
        await txn.execute('ALTER TABLE notes ADD COLUMN color INTEGER');
      }
      if (oldVersion < 3) {
        await txn.execute("ALTER TABLE notes ADD COLUMN folder_name TEXT NOT NULL DEFAULT 'Genel'");
      }
      if (oldVersion < 4) {
        await txn.execute('''
          CREATE VIRTUAL TABLE IF NOT EXISTS notes_fts USING fts5(
            id UNINDEXED,
            title,
            content
          )
        ''');
        await txn.execute('''
          INSERT INTO notes_fts(id, title, content)
          SELECT id, title, content FROM notes
        ''');
      }
      if (oldVersion < 5) {
        await txn.execute('CREATE INDEX IF NOT EXISTS idx_notes_updated_at ON notes(updated_at)');
      }
    });
  }

  @override
  Future<void> close() async {
    final db = _database;
    _database = null;
    _openingFuture = null;

    if (db != null) {
      await db.close();
    }
  }

  @override
  Future<int> insertNote(Map<String, dynamic> note) async {
    final db = await open();

    return db.transaction<int>((txn) async {
      final id = await txn.insert('notes', note);
      await txn.insert('notes_fts', {
        'id': id,
        'title': note['title'],
        'content': note['content'],
      });
      return id;
    });
  }

  @override
  Future<List<Map<String, dynamic>>> getAllNotes() async {
    final db = await open();
    return db.transaction((txn) async {
      return txn.query('notes', orderBy: 'updated_at DESC');
    });
  }

  @override
  Future<List<Map<String, dynamic>>> searchNotes(String query) async {
    final db = await open();
    final escaped = _escapeLike(query);

    return db.transaction((txn) async {
      return txn.query(
        'notes',
        where: r'title LIKE ? ESCAPE "\\" OR content LIKE ? ESCAPE "\\"',
        whereArgs: ['%$escaped%', '%$escaped%'],
        orderBy: 'updated_at DESC',
      );
    });
  }

  @override
  Future<List<Map<String, dynamic>>?> getNoteById(int id) async {
    final db = await open();

    return db.transaction((txn) async {
      final rows = await txn.query(
        'notes',
        where: 'id = ?',
        whereArgs: [id],
        limit: 1,
      );
      return rows.isEmpty ? null : rows;
    });
  }

  @override
  Future<int> updateNote(Map<String, dynamic> note) async {
    final db = await open();

    return db.transaction<int>((txn) async {
      final updatedNote = Map<String, dynamic>.from(note)
        ..['updated_at'] = DateTime.now().millisecondsSinceEpoch;

      final count = await txn.update(
        'notes',
        updatedNote,
        where: 'id = ?',
        whereArgs: [updatedNote['id']],
      );

      if (count > 0) {
        await txn.update(
          'notes_fts',
          {
            'title': updatedNote['title'],
            'content': updatedNote['content'],
          },
          where: 'id = ?',
          whereArgs: [updatedNote['id']],
        );
      }

      return count;
    });
  }

  @override
  Future<int> deleteNote(int id) async {
    final db = await open();

    return db.transaction<int>((txn) async {
      await txn.delete('notes_fts', where: 'id = ?', whereArgs: [id]);
      return txn.delete('notes', where: 'id = ?', whereArgs: [id]);
    });
  }

  @override
  Future<void> replaceBacklinks({
    required int noteId,
    required String content,
    required List<Map<String, dynamic>> allNotes,
  }) async {
    final db = await open();
    final linkRegex = RegExp(r'\[\[([^\]]+)\]\]');
    final matches = linkRegex.allMatches(content);

    await db.transaction((txn) async {
      await txn.delete(
        'backlinks',
        where: 'source_note_id = ?',
        whereArgs: [noteId],
      );

      final titleToId = <String, int>{
        for (final note in allNotes)
          note['title'].toString().toLowerCase(): note['id'] as int,
      };

      for (final match in matches) {
        final linkText = match.group(1);
        if (linkText == null || linkText.trim().isEmpty) {
          continue;
        }

        final targetId = titleToId[linkText.toLowerCase()];
        if (targetId == null) {
          continue;
        }

        await txn.insert('backlinks', {
          'source_note_id': noteId,
          'target_note_id': targetId,
          'link_text': linkText,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
      }
    });
  }

  @override
  Future<int> insertTemplate(Map<String, dynamic> template) async {
    final db = await open();
    return db.transaction((txn) => txn.insert('templates', template));
  }

  @override
  Future<int> updateTemplate(Map<String, dynamic> template) async {
    final db = await open();
    return db.transaction(
      (txn) => txn.update(
        'templates',
        template,
        where: 'id = ?',
        whereArgs: [template['id']],
      ),
    );
  }

  @override
  Future<int> deleteTemplate(int id) async {
    final db = await open();
    return db.transaction(
      (txn) => txn.delete('templates', where: 'id = ?', whereArgs: [id]),
    );
  }

  @override
  Future<List<Map<String, dynamic>>> getAllTemplates() async {
    final db = await open();
    return db.transaction(
      (txn) => txn.query('templates', orderBy: 'created_at DESC'),
    );
  }

  String _escapeLike(String value) {
    return value
        .replaceAll('\\', '\\\\')
        .replaceAll('%', '\\%')
        .replaceAll('_', '\\_');
  }
}
