import '../models/note_model.dart';

/// Mock implementation of INoteRepository for testing
/// Follows Dependency Inversion Principle: Can be easily swapped with real implementation
class MockNoteRepository implements INoteRepository {
  final List<Note> _notes = [];
  int _nextId = 1;

  @override
  Future<int> insertNote(Note note) async {
    final newNote = note.copyWith(id: _nextId++);
    _notes.add(newNote);
    return newNote.id!;
  }

  @override
  Future<Note?> getNoteById(int id) async {
    try {
      return _notes.firstWhere((note) => note.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<Note>> getAllNotes() async {
    return List.from(_notes);
  }

  @override
  Future<int> updateNote(Note note) async {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _notes[index] = note;
      return 1;
    }
    return 0;
  }

  @override
  Future<int> deleteNote(int id) async {
    _notes.removeWhere((note) => note.id == id);
    return 1;
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    if (query.isEmpty) return getAllNotes();
    
    final lowerQuery = query.toLowerCase();
    return _notes.where((note) =>
        note.title.toLowerCase().contains(lowerQuery) ||
        note.content.toLowerCase().contains(lowerQuery)
    ).toList();
  }

  @override
  Future<List<Note>> getRecentNotes({int limit = 5}) async {
    final sortedNotes = List.from(_notes)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sortedNotes.take(limit).toList();
  }

  @override
  Future<List<Note>> getPendingTasks({int limit = 10}) async {
    return _notes
        .where((note) => note.content.contains('- [ '))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt))
      ..take(limit);
  }

  @override
  Future<List<Note>> getNotesByFolder(String folderName) async {
    return _notes.where((note) => note.folderName == folderName).toList();
  }

  @override
  Future<List<Note>> getNotesByTag(String tag) async {
    return _notes.where((note) => note.tags.contains(tag)).toList();
  }

  @override
  Future<List<String>> getAllFolders() async {
    final folderSet = _notes
        .map((note) => note.folderName)
        .where((folder) => folder.isNotEmpty)
        .toSet();
    
    if (!folderSet.contains('Genel')) {
      folderSet.add('Genel');
    }
    
    return folderSet.toList()..sort();
  }

  @override
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final totalTasks = _notes.where((note) => note.content.contains('- [ ')).length;
    final lastNoteDate = _notes.isNotEmpty ? 
        _notes.map((n) => n.updatedAt).reduce((a, b) => a > b ? a : b) : null;
    
    return {
      'totalNotes': _notes.length,
      'totalTasks': totalTasks,
      'lastNoteDate': lastNoteDate,
    };
  }

  @override
  Future<void> insertNotes(List<Note> notes) async {
    for (final note in notes) {
      await insertNote(note);
    }
  }

  @override
  Future<void> deleteNotes(List<int> noteIds) async {
    _notes.removeWhere((note) => noteIds.contains(note.id));
  }

  @override
  Future<List<Map<String, dynamic>>> exportAllNotes() async {
    return _notes.map((note) => note.toJson()).toList();
  }

  @override
  Future<void> importNotes(List<Map<String, dynamic>> notesData) async {
    final notes = notesData.map((data) => Note.fromJson(data)).toList();
    await insertNotes(notes);
  }

  /// Helper method for testing - add sample data
  void addSampleData() {
    _notes.addAll([
      Note(
        id: _nextId++,
        title: 'Test Note 1',
        content: 'This is a test note with some content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        tags: ['test', 'sample'],
      ),
      Note(
        id: _nextId++,
        title: 'Test Note 2',
        content: 'Another test note - [ ] incomplete task',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        tags: ['test'],
      ),
    ]);
  }

  /// Clear all notes for testing
  void clearAll() {
    _notes.clear();
    _nextId = 1;
  }
}
