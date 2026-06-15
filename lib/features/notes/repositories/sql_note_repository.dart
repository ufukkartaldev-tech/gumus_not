import '../models/note_model.dart';
import '../../../core/database/idatabase_service.dart';
import '../../../core/database/sqlite_database_service.dart';
import 'note_repository.dart';

/// Concrete implementation of [NoteRepository] using an injected database
/// service.
///
/// The repository intentionally depends on the legacy [IDatabaseService]
/// contract so existing callers remain stable. In the new architecture this
/// contract is fulfilled by [LegacyDatabaseServiceAdapter], which internally
/// routes all persistence to the secure transaction-based database layer.
class SqlNoteRepository implements NoteRepository {
  SqlNoteRepository([IDatabaseService? databaseService])
      : _databaseService = databaseService ?? SqliteDatabaseService();

  final IDatabaseService _databaseService;

  @override
  Future<int> insertNote(Note note) async {
    return _databaseService.insertNote(note.toMap());
  }

  @override
  Future<int> addNote(Note note) async {
    return _databaseService.insertNote(note.toMap());
  }

  @override
  Future<Note?> getNoteById(int id) async {
    final maps = await _databaseService.getNoteById(id);
    if (maps == null || maps.isEmpty) return null;
    return Note.fromMap(maps.first);
  }

  @override
  Future<List<Note>> getAllNotes() async {
    final maps = await _databaseService.getAllNotes();
    return maps.map(Note.fromMap).toList();
  }

  @override
  Future<int> updateNote(Note note) async {
    return _databaseService.updateNote(note.toMap());
  }

  @override
  Future<int> deleteNote(int id) async {
    return _databaseService.deleteNote(id);
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    final maps = await _databaseService.searchNotes(query);
    return maps.map(Note.fromMap).toList();
  }

  @override
  Future<List<Note>> getRecentNotes({int limit = 5}) async {
    final maps = await _databaseService.getRecentNotes(limit: limit);
    return maps.map(Note.fromMap).toList();
  }

  @override
  Future<List<Note>> getPendingTasks({int limit = 10}) async {
    final maps = await _databaseService.getPendingTasks(limit: limit);
    return maps.map(Note.fromMap).toList();
  }

  @override
  Future<List<Note>> getNotesByFolder(String folderName) async {
    final allNotes = await getAllNotes();
    return allNotes.where((note) => note.folderName == folderName).toList();
  }

  @override
  Future<List<Note>> getNotesByTag(String tag) async {
    final allNotes = await getAllNotes();
    return allNotes.where((note) => note.tags.contains(tag)).toList();
  }

  @override
  Future<List<String>> getAllFolders() async {
    final allNotes = await getAllNotes();
    final folderSet = allNotes
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
    return _databaseService.getDatabaseStats();
  }

  @override
  Future<void> insertNotes(List<Note> notes) async {
    await _databaseService.insertNotes(notes.map((note) => note.toMap()).toList());
  }

  @override
  Future<void> deleteNotes(List<int> noteIds) async {
    await _databaseService.deleteNotes(noteIds);
  }

  @override
  Future<List<Map<String, dynamic>>> exportAllNotes() async {
    final notes = await getAllNotes();
    return notes.map((note) => note.toJson()).toList();
  }

  @override
  Future<void> importNotes(List<Map<String, dynamic>> notesData) async {
    final notes = notesData.map(Note.fromJson).toList();
    await insertNotes(notes);
  }

  @override
  Future<List<Backlink>> getBacklinksForNote(int noteId) async {
    final maps = await _databaseService.getBacklinksForNote(noteId);
    return maps.map(Backlink.fromMap).toList();
  }

  @override
  Future<List<Backlink>> getOutgoingLinksForNote(int noteId) async {
    final maps = await _databaseService.getOutgoingLinksForNote(noteId);
    return maps.map(Backlink.fromMap).toList();
  }

  @override
  Future<void> updateBacklinks(Note note, List<Note> allNotes) async {
    await _databaseService.updateBacklinks(
      note.id,
      note.content,
      allNotes.map((n) => n.toMap()).toList(),
    );
  }

  @override
  Future<int> getNoteCountInFolder(String folderName) async {
    return _databaseService.getNoteCountInFolder(folderName);
  }

  @override
  Future<List<String>> getFolders() async {
    return getAllFolders();
  }

  @override
  Future<Map<String, int>> getTagFrequency() async {
    final notes = await getAllNotes();
    final frequency = <String, int>{};

    for (final note in notes) {
      for (final tag in note.tags) {
        frequency[tag] = (frequency[tag] ?? 0) + 1;
      }
    }

    return frequency;
  }

  /// Release the underlying database handle when the repository owns a
  /// close-capable implementation.
  Future<void> close() async {
    await _databaseService.close();
  }
}
