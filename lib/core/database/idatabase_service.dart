import 'package:sqflite/sqflite.dart';

/// Abstract interface for database operations
/// Following SOLID principles: Interface Segregation and Dependency Inversion
abstract class IDatabaseService {
  // Core database operations
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
  Future<int> updateTemplate(Map<String, dynamic> template);
  Future<int> deleteTemplate(int id);

  // Query operations
  Future<List<Map<String, dynamic>>> getRecentNotes({int limit = 5});
  Future<List<Map<String, dynamic>>> getPendingTasks({int limit = 10});
  Future<int> getNoteCountInFolder(String folderName);
  Future<Map<String, dynamic>> getDatabaseStats();

  // Batch operations
  Future<void> insertNotes(List<Map<String, dynamic>> notes);
  Future<void> deleteNotes(List<int> noteIds);

  // Database management
  Future<void> backup(String path);
  Future<void> restore(String path);
  Future<void> vacuum();
  Future<void> optimize();
}

class InMemoryDatabaseService implements IDatabaseService {
  final List<Map<String, dynamic>> _notes = [];
  final List<Map<String, dynamic>> _backlinks = [];
  final List<Map<String, dynamic>> _templates = [];
  int _noteIdCounter = 1;

  @override
  Future<Database> get database async {
    throw UnsupportedError(
      'In-memory web database does not expose a sqflite Database instance.',
    );
  }

  @override
  Future<void> close() async {}

  @override
  Future<int> insertNote(Map<String, dynamic> note) async {
    final id = _noteIdCounter++;
    final newNote = Map<String, dynamic>.from(note)..['id'] = id;
    _notes.add(newNote);
    _sortNotes();
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> getAllNotes() async {
    _sortNotes();
    return _notes.map((note) => Map<String, dynamic>.from(note)).toList();
  }

  @override
  Future<List<Map<String, dynamic>>?> getNoteById(int id) async {
    final matches = _notes.where((note) => note['id'] == id).toList();
    if (matches.isEmpty) return null;
    return matches.map((note) => Map<String, dynamic>.from(note)).toList();
  }

  @override
  Future<int> updateNote(Map<String, dynamic> note) async {
    final index = _notes.indexWhere((item) => item['id'] == note['id']);
    if (index == -1) return 0;

    final updated = Map<String, dynamic>.from(note)
      ..['updated_at'] = DateTime.now().millisecondsSinceEpoch;
    _notes[index] = updated;
    _sortNotes();
    return 1;
  }

  @override
  Future<int> deleteNote(int id) async {
    _backlinks.removeWhere(
      (link) => link['source_note_id'] == id || link['target_note_id'] == id,
    );
    final before = _notes.length;
    _notes.removeWhere((note) => note['id'] == id);
    return _notes.length < before ? 1 : 0;
  }

  @override
  Future<List<Map<String, dynamic>>> searchNotes(String query) async {
    final normalized = query.toLowerCase();
    return _notes
        .where(
          (note) =>
              note['title'].toString().toLowerCase().contains(normalized) ||
              note['content'].toString().toLowerCase().contains(normalized),
        )
        .map((note) => Map<String, dynamic>.from(note))
        .toList();
  }

  @override
  Future<void> insertBacklink(Map<String, dynamic> backlink) async {
    _backlinks.add(Map<String, dynamic>.from(backlink));
  }

  @override
  Future<List<Map<String, dynamic>>> getBacklinksForNote(int noteId) async {
    return _backlinks
        .where((link) => link['target_note_id'] == noteId)
        .map((link) => Map<String, dynamic>.from(link))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getOutgoingLinksForNote(int noteId) async {
    return _backlinks
        .where((link) => link['source_note_id'] == noteId)
        .map((link) => Map<String, dynamic>.from(link))
        .toList();
  }

  @override
  Future<void> updateBacklinks(
    int? noteId,
    String content,
    List<Map<String, dynamic>> allNotes,
  ) async {
    if (noteId == null) return;

    _backlinks.removeWhere((link) => link['source_note_id'] == noteId);
    final matches = RegExp(r'\[\[([^\]]+)\]\]').allMatches(content);

    for (final match in matches) {
      final linkText = match.group(1)?.trim();
      if (linkText == null || linkText.isEmpty) continue;

      Map<String, dynamic>? target;
      for (final note in allNotes) {
        if (note['title'].toString().toLowerCase() == linkText.toLowerCase()) {
          target = note;
          break;
        }
      }

      if (target != null && target['id'] != null) {
        _backlinks.add({
          'source_note_id': noteId,
          'target_note_id': target['id'],
          'link_text': linkText,
          'created_at': DateTime.now().millisecondsSinceEpoch,
        });
      }
    }
  }

  @override
  Future<int> insertTemplate(Map<String, dynamic> template) async {
    final id = _templates.length + 1;
    final newTemplate = Map<String, dynamic>.from(template)..['id'] = id;
    _templates.add(newTemplate);
    return id;
  }

  @override
  Future<List<Map<String, dynamic>>> getAllTemplates() async {
    return _templates
        .map((template) => Map<String, dynamic>.from(template))
        .toList();
  }

  @override
  Future<int> updateTemplate(Map<String, dynamic> template) async {
    final index = _templates.indexWhere((item) => item['id'] == template['id']);
    if (index == -1) return 0;
    _templates[index] = Map<String, dynamic>.from(template);
    return 1;
  }

  @override
  Future<int> deleteTemplate(int id) async {
    final before = _templates.length;
    _templates.removeWhere((template) => template['id'] == id);
    return _templates.length < before ? 1 : 0;
  }

  @override
  Future<List<Map<String, dynamic>>> getRecentNotes({int limit = 5}) async {
    _sortNotes();
    return _notes
        .take(limit)
        .map((note) => Map<String, dynamic>.from(note))
        .toList();
  }

  @override
  Future<List<Map<String, dynamic>>> getPendingTasks({int limit = 10}) async {
    return _notes
        .where((note) => note['content'].toString().contains('- [ ]'))
        .take(limit)
        .map((note) => Map<String, dynamic>.from(note))
        .toList();
  }

  @override
  Future<int> getNoteCountInFolder(String folderName) async {
    return _notes.where((note) => note['folder_name'] == folderName).length;
  }

  @override
  Future<Map<String, dynamic>> getDatabaseStats() async {
    return {
      'totalNotes': _notes.length,
      'encryptedNotes': _notes
          .where(
            (note) => note['is_encrypted'] == 1 || note['is_encrypted'] == true,
          )
          .length,
      'templates': _templates.length,
    };
  }

  @override
  Future<void> insertNotes(List<Map<String, dynamic>> notes) async {
    for (final note in notes) {
      await insertNote(note);
    }
  }

  @override
  Future<void> deleteNotes(List<int> noteIds) async {
    for (final noteId in noteIds) {
      await deleteNote(noteId);
    }
  }

  @override
  Future<void> backup(String path) async {}

  @override
  Future<void> restore(String path) async {}

  @override
  Future<void> vacuum() async {}

  @override
  Future<void> optimize() async {}

  void _sortNotes() {
    _notes.sort(
      (a, b) => (b['updated_at'] as int? ?? 0).compareTo(
        a['updated_at'] as int? ?? 0,
      ),
    );
  }
}
