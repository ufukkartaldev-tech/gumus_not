import 'dart:async';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/repositories/note_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

/// SQLite FTS5 constants
class Fts5Constants {
  static const String ftsTableName = 'notes_fts';
  static const String ftsContentColumn = 'content';
  static const String ftsTitleColumn = 'title';
  static const String ftsTagsColumn = 'tags';
  
  // FTS5 tokenizer configuration
  static const String ftsTokenizer = 'porter unicode61';
  
  // Search patterns
  static const String pendingTaskPattern = '- [ ]';
  static const String completedTaskPattern = '- [x]';
  static const String taskPattern = '- [';
}

/// Optimized SQLite repository with FTS5 and triggers
class OptimizedSqliteNoteRepository implements NoteRepository {
  Database? _database;
  static const String _dbName = 'connected_notebook_optimized.db';
  static const int _dbVersion = 4; // Incremented for FTS5
  
  // Performance monitoring
  final Map<String, int> _operationCounts = {};
  final Stopwatch _queryStopwatch = Stopwatch();
  
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }
    await _createMainTables(db);
    await _createFts5Table(db);
    await _createIndexes(db);
    await _createTriggers(db);
  }
  
  Future<void> _createMainTables(Database db) async {
    // Main notes table
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
        folder_name TEXT DEFAULT 'Genel',
        
        -- Computed columns for performance
        has_pending_tasks INTEGER GENERATED ALWAYS AS (
          CASE WHEN content LIKE '%${Fts5Constants.pendingTaskPattern}%' THEN 1 ELSE 0 END
        ) STORED,
        task_count INTEGER GENERATED ALWAYS AS (
          (LENGTH(content) - LENGTH(REPLACE(content, '${Fts5Constants.taskPattern}', ''))) / 
          LENGTH('${Fts5Constants.taskPattern}')
        ) STORED,
        word_count INTEGER GENERATED ALWAYS AS (
          LENGTH(TRIM(content)) - LENGTH(REPLACE(TRIM(content), ' ', '')) + 1
        ) STORED
      )
    ''');
    
    // Backlinks table
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
  }
  
  Future<void> _createFts5Table(Database db) async {
    // Create FTS5 virtual table for full-text search
    await db.execute('''
      CREATE VIRTUAL TABLE ${Fts5Constants.ftsTableName} 
      USING fts5(
        ${Fts5Constants.ftsTitleColumn},
        ${Fts5Constants.ftsContentColumn},
        ${Fts5Constants.ftsTagsColumn},
        content='notes',
        content_rowid='id',
        tokenize='${Fts5Constants.ftsTokenizer}'
      )
    ''');
    
    // Create FTS5 configuration table
    await db.execute('''
      INSERT INTO ${Fts5Constants.ftsTableName}(
        ${Fts5Constants.ftsTableName}, 
        rank
      ) VALUES('rank', 'bm25(1.0, 0.5, 0.3)')
    ''');
  }
  
  Future<void> _createIndexes(Database db) async {
    // B-tree indexes for common queries
    await db.execute('''
      CREATE INDEX idx_notes_updated_at ON notes(updated_at DESC)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_notes_created_at ON notes(created_at DESC)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_notes_folder ON notes(folder_name)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_notes_pending_tasks ON notes(has_pending_tasks)
      WHERE has_pending_tasks = 1
    ''');
    
    await db.execute('''
      CREATE INDEX idx_backlinks_source ON backlinks(source_note_id)
    ''');
    
    await db.execute('''
      CREATE INDEX idx_backlinks_target ON backlinks(target_note_id)
    ''');
    
    // Covering index for common queries
    await db.execute('''
      CREATE INDEX idx_notes_cover_list ON notes(
        id, title, updated_at, folder_name, has_pending_tasks
      )
    ''');
  }
  
  Future<void> _createTriggers(Database db) async {
    // Triggers to keep FTS5 table synchronized
    
    // Insert trigger
    await db.execute('''
      CREATE TRIGGER notes_ai AFTER INSERT ON notes BEGIN
        INSERT INTO ${Fts5Constants.ftsTableName}(
          rowid, 
          ${Fts5Constants.ftsTitleColumn}, 
          ${Fts5Constants.ftsContentColumn}, 
          ${Fts5Constants.ftsTagsColumn}
        ) VALUES (
          new.id, 
          new.title, 
          new.content, 
          new.tags
        );
      END
    ''');
    
    // Update trigger
    await db.execute('''
      CREATE TRIGGER notes_au AFTER UPDATE ON notes BEGIN
        UPDATE ${Fts5Constants.ftsTableName} SET
          ${Fts5Constants.ftsTitleColumn} = new.title,
          ${Fts5Constants.ftsContentColumn} = new.content,
          ${Fts5Constants.ftsTagsColumn} = new.tags
        WHERE rowid = old.id;
      END
    ''');
    
    // Delete trigger
    await db.execute('''
      CREATE TRIGGER notes_ad AFTER DELETE ON notes BEGIN
        DELETE FROM ${Fts5Constants.ftsTableName} WHERE rowid = old.id;
      END
    ''');
  }
  
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    // Migration from version 3 to 4 (adding FTS5)
    if (oldVersion < 4) {
      await _migrateToFts5(db);
    }
  }
  
  Future<void> _migrateToFts5(Database db) async {
    // Create FTS5 table
    await _createFts5Table(db);
    
    // Populate FTS5 table with existing data
    await db.execute('''
      INSERT INTO ${Fts5Constants.ftsTableName}(
        rowid, 
        ${Fts5Constants.ftsTitleColumn}, 
        ${Fts5Constants.ftsContentColumn}, 
        ${Fts5Constants.ftsTagsColumn}
      )
      SELECT 
        id, 
        title, 
        content, 
        tags
      FROM notes
    ''');
    
    // Create triggers
    await _createTriggers(db);
    
    // Add generated columns
    await db.execute('''
      ALTER TABLE notes ADD COLUMN has_pending_tasks INTEGER GENERATED ALWAYS AS (
        CASE WHEN content LIKE '%${Fts5Constants.pendingTaskPattern}%' THEN 1 ELSE 0 END
      ) STORED
    ''');
    
    await db.execute('''
      ALTER TABLE notes ADD COLUMN task_count INTEGER GENERATED ALWAYS AS (
        (LENGTH(content) - LENGTH(REPLACE(content, '${Fts5Constants.taskPattern}', ''))) / 
        LENGTH('${Fts5Constants.taskPattern}')
      ) STORED
    ''');
    
    await db.execute('''
      ALTER TABLE notes ADD COLUMN word_count INTEGER GENERATED ALWAYS AS (
        LENGTH(TRIM(content)) - LENGTH(REPLACE(TRIM(content), ' ', '')) + 1
      ) STORED
    ''');
    
    // Create new indexes
    await _createIndexes(db);
  }
  
  // Performance tracking
  void _startQueryTimer() {
    _queryStopwatch.start();
  }
  
  Map<String, dynamic> _endQueryTimer(String operation) {
    _queryStopwatch.stop();
    final elapsed = _queryStopwatch.elapsedMilliseconds;
    _queryStopwatch.reset();
    
    _operationCounts[operation] = (_operationCounts[operation] ?? 0) + 1;
    
    return {
      'operation': operation,
      'duration_ms': elapsed,
      'count': _operationCounts[operation],
    };
  }
  
  @override
  Future<List<Note>> getAllNotes() async {
    _startQueryTimer();
    
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      orderBy: 'updated_at DESC',
    );
    
    final stats = _endQueryTimer('getAllNotes');
    print('Query stats: $stats');
    
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }
  
  @override
  Future<Note?> getNoteById(int id) async {
    _startQueryTimer();
    
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    _endQueryTimer('getNoteById');
    
    if (maps.isNotEmpty) {
      return Note.fromMap(maps.first);
    }
    return null;
  }
  
  @override
  Future<List<Note>> searchNotes(String query) async {
    _startQueryTimer();
    
    if (query.isEmpty) {
      return getAllNotes();
    }
    
    final db = await _db;
    
    // Use FTS5 for full-text search
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT n.*, 
             fts.rank as search_rank,
             snippet(${Fts5Constants.ftsTableName}, 0, '<b>', '</b>', '...', 64) as snippet
      FROM notes n
      JOIN ${Fts5Constants.ftsTableName} fts ON n.id = fts.rowid
      WHERE ${Fts5Constants.ftsTableName} MATCH ?
      ORDER BY fts.rank DESC, n.updated_at DESC
      LIMIT 100
    ''', [query]);
    
    final stats = _endQueryTimer('searchNotes');
    print('FTS5 search stats: $stats');
    
    return List.generate(maps.length, (i) {
      final map = maps[i];
      // Remove FTS5-specific columns before creating Note
      map.remove('search_rank');
      map.remove('snippet');
      return Note.fromMap(map);
    });
  }
  
  @override
  Future<int> addNote(Note note) async {
    _startQueryTimer();
    
    final db = await _db;
    final id = await db.insert('notes', note.toMap());
    
    _endQueryTimer('addNote');
    return id;
  }
  
  @override
  Future<void> updateNote(Note note) async {
    _startQueryTimer();
    
    final db = await _db;
    note.updatedAt = DateTime.now().millisecondsSinceEpoch;
    
    await db.update(
      'notes',
      note.toMap(),
      where: 'id = ?',
      whereArgs: [note.id],
    );
    
    _endQueryTimer('updateNote');
  }
  
  @override
  Future<void> deleteNote(int id) async {
    _startQueryTimer();
    
    final db = await _db;
    await db.delete(
      'notes',
      where: 'id = ?',
      whereArgs: [id],
    );
    
    _endQueryTimer('deleteNote');
  }
  
  @override
  Future<List<Note>> getRecentNotes({int limit = 5}) async {
    _startQueryTimer();
    
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    
    _endQueryTimer('getRecentNotes');
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }
  
  @override
  Future<List<Note>> getPendingTasks({int limit = 10}) async {
    _startQueryTimer();
    
    final db = await _db;
    
    // Use indexed generated column instead of LIKE
    final List<Map<String, dynamic>> maps = await db.query(
      'notes',
      where: 'has_pending_tasks = 1',
      orderBy: 'updated_at DESC',
      limit: limit,
    );
    
    final stats = _endQueryTimer('getPendingTasks');
    print('Pending tasks query stats: $stats');
    
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }
  
  @override
  Future<Map<String, dynamic>> getDatabaseStats() async {
    _startQueryTimer();
    
    final db = await _db;
    
    // Use efficient queries with indexes
    final totalNotesResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM notes
    ''');
    
    final totalTasksResult = await db.rawQuery('''
      SELECT COUNT(*) as count FROM notes WHERE has_pending_tasks = 1
    ''');
    
    final lastNoteResult = await db.query(
      'notes',
      columns: ['updated_at'],
      orderBy: 'updated_at DESC',
      limit: 1,
    );
    
    // FTS5 statistics
    final ftsStatsResult = await db.rawQuery('''
      SELECT 
        COUNT(*) as fts_document_count,
        AVG(LENGTH(${Fts5Constants.ftsContentColumn})) as avg_content_length
      FROM ${Fts5Constants.ftsTableName}
    ''');
    
    // Index usage statistics (SQLite pragma)
    final indexStats = <String, dynamic>{};
    try {
      final indexList = await db.rawQuery('PRAGMA index_list(notes)');
      for (final index in indexList) {
        final indexName = index['name'] as String;
        final indexInfo = await db.rawQuery('PRAGMA index_info($indexName)');
        indexStats[indexName] = indexInfo.length;
      }
    } catch (e) {
      // Pragmas might not work in all environments
      print('Index stats error: $e');
    }
    
    final stats = _endQueryTimer('getDatabaseStats');
    
    return {
      'totalNotes': totalNotesResult.first['count'],
      'totalTasks': totalTasksResult.first['count'],
      'lastNoteDate': lastNoteResult.isNotEmpty ? lastNoteResult.first['updated_at'] : null,
      'ftsDocumentCount': ftsStatsResult.first['fts_document_count'],
      'avgContentLength': ftsStatsResult.first['avg_content_length'],
      'indexStats': indexStats,
      'operationStats': stats,
      'totalOperations': _operationCounts.values.fold(0, (sum, count) => sum + count),
    };
  }
  
  @override
  Future<List<Backlink>> getBacklinksForNote(int noteId) async {
    _startQueryTimer();
    
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'backlinks',
      where: 'target_note_id = ?',
      whereArgs: [noteId],
      orderBy: 'created_at DESC',
    );
    
    _endQueryTimer('getBacklinksForNote');
    return List.generate(maps.length, (i) => Backlink.fromMap(maps[i]));
  }
  
  @override
  Future<List<Backlink>> getOutgoingLinksForNote(int noteId) async {
    _startQueryTimer();
    
    final db = await _db;
    final List<Map<String, dynamic>> maps = await db.query(
      'backlinks',
      where: 'source_note_id = ?',
      whereArgs: [noteId],
      orderBy: 'created_at DESC',
    );
    
    _endQueryTimer('getOutgoingLinksForNote');
    return List.generate(maps.length, (i) => Backlink.fromMap(maps[i]));
  }
  
  @override
  Future<void> updateBacklinks(Note note, List<Note> allNotes) async {
    _startQueryTimer();
    
    final db = await _db;
    
    // Use transaction for atomicity
    await db.transaction((txn) async {
      // Delete existing backlinks from this note
      await txn.delete(
        'backlinks',
        where: 'source_note_id = ?',
        whereArgs: [note.id],
      );
      
      // Extract links from content
      final RegExp linkRegex = RegExp(r'\[\[([^\]]+)\]\]');
      final matches = linkRegex.allMatches(note.content);
      
      // Prepare batch insert
      final batch = txn.batch();
      
      for (final match in matches) {
        final linkText = match.group(1)!;
        
        // Find target note using efficient lookup
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
        
        if (targetNote.id != -1) {
          final backlink = Backlink(
            sourceNoteId: note.id!,
            targetNoteId: targetNote.id!,
            linkText: linkText,
            createdAt: DateTime.now().millisecondsSinceEpoch,
          );
          batch.insert('backlinks', backlink.toMap());
        }
      }
      
      await batch.commit();
    });
    
    _endQueryTimer('updateBacklinks');
  }
  
  @override
  Future<List<String>> getFolders() async {
    _startQueryTimer();
    
    final db = await _db;
    
    // Use DISTINCT and index
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT DISTINCT folder_name 
      FROM notes 
      WHERE folder_name IS NOT NULL AND folder_name != ''
      UNION
      SELECT 'Genel' as folder_name
      ORDER BY folder_name
    ''');
    
    _endQueryTimer('getFolders');
    return maps.map((map) => map['folder_name'] as String).toList();
  }
  
  @override
  Future<int> getNoteCountInFolder(String folderName) async {
    _startQueryTimer();
    
    final db = await _db;
    
    final result = await db.rawQuery('''
      SELECT COUNT(*) as count 
      FROM notes 
      WHERE folder_name = ?
    ''', [folderName]);
    
    _endQueryTimer('getNoteCountInFolder');
    return result.first['count'] as int;
  }
  
  @override
  Future<List<Note>> getNotesByTag(String tag) async {
    _startQueryTimer();
    
    final db = await _db;
    
    // Use FTS5 for tag search
    final List<Map<String, dynamic>> maps = await db.rawQuery('''
      SELECT n.*
      FROM notes n
      JOIN ${Fts5Constants.ftsTableName} fts ON n.id = fts.rowid
      WHERE ${Fts5Constants.ftsTagsColumn} MATCH ?
      ORDER BY n.updated_at DESC
    ''', [tag]);
    
    _endQueryTimer('getNotesByTag');
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }
  
  @override
  Future<Map<String, int>> getTagFrequency() async {
    _startQueryTimer();
    
    final db = await _db;
    final notes = await getAllNotes();
    
    final Map<String, int> tagFrequency = {};
    for (final note in notes) {
      for (final tag in note.tags) {
        tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
      }
    }
    
    _endQueryTimer('getTagFrequency');
    return tagFrequency;
  }
  
  /// Advanced search with multiple criteria
  Future<List<Note>> advancedSearch({
    String? query,
    String? folder,
    List<String>? tags,
    bool? hasPendingTasks,
    DateTime? createdAfter,
    DateTime? updatedAfter,
    int limit = 50,
  }) async {
    _startQueryTimer();
    
    final db = await _db;
    final whereClauses = <String>[];
    final whereArgs = <dynamic>[];
    
    // Build WHERE clause dynamically
    if (query != null && query.isNotEmpty) {
      whereClauses.add('''
        id IN (
          SELECT rowid FROM ${Fts5Constants.ftsTableName} 
          WHERE ${Fts5Constants.ftsTableName} MATCH ?
        )
      ''');
      whereArgs.add(query);
    }
    
    if (folder != null) {
      whereClauses.add('folder_name = ?');
      whereArgs.add(folder);
    }
    
    if (hasPendingTasks != null) {
      whereClauses.add('has_pending_tasks = ?');
      whereArgs.add(hasPendingTasks ? 1 : 0);
    }
    
    if (createdAfter != null) {
      whereClauses.add('created_at >= ?');
      whereArgs.add(createdAfter.millisecondsSinceEpoch);
    }
    
    if (updatedAfter != null) {
      whereClauses.add('updated_at >= ?');
      whereArgs.add(updatedAfter.millisecondsSinceEpoch);
    }
    
    // Tag search using FTS5
    if (tags != null && tags.isNotEmpty) {
      final tagConditions = tags.map((tag) => '${Fts5Constants.ftsTagsColumn} MATCH ?').toList();
      whereClauses.add('''
        id IN (
          SELECT rowid FROM ${Fts5Constants.ftsTableName} 
          WHERE ${tagConditions.join(' OR ')}
        )
      ''');
      whereArgs.addAll(tags);
    }
    
    final whereClause = whereClauses.isNotEmpty 
        ? 'WHERE ${whereClauses.join(' AND ')}'
        : '';
    
    final sql = '''
      SELECT * FROM notes
      $whereClause
      ORDER BY updated_at DESC
      LIMIT ?
    ''';
    
    final allArgs = [...whereArgs, limit];
    final List<Map<String, dynamic>> maps = await db.rawQuery(sql, allArgs);
    
    final stats = _endQueryTimer('advancedSearch');
    print('Advanced search stats: $stats');
    
    return List.generate(maps.length, (i) => Note.fromMap(maps[i]));
  }
  
  /// Optimize database performance
  Future<void> optimizeDatabase() async {
    _startQueryTimer();
    
    final db = await _db;
    
    // Run optimization commands
    await db.execute('PRAGMA optimize');
    await db.execute('VACUUM');
    await db.execute('ANALYZE');
    
    // Rebuild FTS5 table if needed
    await db.execute('''
      INSERT INTO ${Fts5Constants.ftsTableName}(
        ${Fts5Constants.ftsTableName}
      ) VALUES('rebuild')
    ''');
    
    _endQueryTimer('optimizeDatabase');
    print('Database optimization completed');
  }
  
  /// Get query performance statistics
  Map<String, dynamic> getPerformanceStats() {
    return {
      'operationCounts': Map.from(_operationCounts),
      'totalOperations': _operationCounts.values.fold(0, (sum, count) => sum + count),
    };
  }
  
  /// Close database connection
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}