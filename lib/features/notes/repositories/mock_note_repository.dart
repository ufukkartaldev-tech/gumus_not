import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/repositories/note_repository.dart';

/// Mock repository for testing
class MockNoteRepository implements NoteRepository {
  final List<Note> _mockNotes = [];

  @override
  Future<List<Note>> getAllNotes() async {
    return List.from(_mockNotes);
  }

  @override
  Future<Note?> getNoteById(int id) async {
    try {
      return _mockNotes.firstWhere((note) => note.id == id);
    } catch (e) {
      return null;
    }
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    return _mockNotes.where((note) =>
      note.title.toLowerCase().contains(query.toLowerCase()) ||
      note.content.toLowerCase().contains(query.toLowerCase())
    ).toList();
  }

  @override
  Future<int> addNote(Note note) async {
    final newId = _mockNotes.isEmpty ? 1 : (_mockNotes.last.id ?? 0) + 1;
    final newNote = note.copyWith(id: newId);
    _mockNotes.add(newNote);
    return newId;
  }


  @override
  Future<void> updateNote(Note note) async {
    final index = _mockNotes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _mockNotes[index] = note;
    }
  }

  @override
  Future<void> deleteNote(int id) async {
    _mockNotes.removeWhere((note) => note.id == id);
  }

  @override
  Future<List<Note>> getRecentNotes({int limit = 5}) async {
    final sorted = List.from(_mockNotes)
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return sorted.take(limit).toList().cast<Note>();
  }

  @override
  Future<List<Note>> getPendingTasks({int limit = 10}) async {
    return _mockNotes
        .where((note) => note.content.contains('- [ ]'))
        .take(limit)
        .toList();
  }

  @override
  Future<Map<String, dynamic>> getDatabaseStats() async {
    return {
      'totalNotes': _mockNotes.length,
      'totalTasks': _mockNotes.where((n) => n.content.contains('- [ ]')).length,
      'lastNoteDate': _mockNotes.isNotEmpty
          ? _mockNotes.map((n) => n.updatedAt).reduce((a, b) => a > b ? a : b)
          : null,
    };
  }



  @override
  Future<List<Note>> getNotesByTag(String tag) async {
    return _mockNotes.where((note) => note.tags.contains(tag)).toList();
  }



  @override
  Future<List<Backlink>> getBacklinksForNote(int noteId) async {
    return [];
  }

  @override
  Future<List<Backlink>> getOutgoingLinksForNote(int noteId) async {
    return [];
  }

  @override
  Future<void> updateBacklinks(Note note, List<Note> allNotes) async {}

  @override
  Future<List<String>> getFolders() async {
    final folderSet = _mockNotes.map((n) => n.folderName).where((f) => f.isNotEmpty).toSet();
    if (!folderSet.contains('Genel')) folderSet.add('Genel');
    return folderSet.toList()..sort();
  }

  @override
  Future<int> getNoteCountInFolder(String folderName) async {
    return _mockNotes.where((n) => n.folderName == folderName).length;
  }

  @override
  Future<Map<String, int>> getTagFrequency() async {
    final frequency = <String, int>{};
    for (final note in _mockNotes) {
      for (final tag in note.tags) {
        frequency[tag] = (frequency[tag] ?? 0) + 1;
      }
    }
    return frequency;
  }

  /// Helper method to add mock data for testing
  void addMockNotes(List<Note> notes) {
    _mockNotes.addAll(notes);
  }

  /// Helper method to clear mock data (alias for clear)
  void clearAll() {
    clear();
  }

  /// Helper method to clear mock data
  void clear() {
    _mockNotes.clear();
  }
}
