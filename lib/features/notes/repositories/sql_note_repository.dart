import '../models/note_model.dart';
import '../../../core/database/idatabase_service.dart';
import '../../../core/database/database_service.dart';
import 'note_repository.dart';

/// Concrete implementation of NoteRepository using SQLite
/// Follows Single Responsibility Principle: Only handles note data operations
class SqlNoteRepository implements NoteRepository {
  final IDatabaseService _databaseService;

  SqlNoteRepository([IDatabaseService? databaseService]) 
      : _databaseService = databaseService ?? SqliteDatabaseService();
  
  @override
  Future<int> insertNote(Note note) async {
    return await _databaseService.insertNote(note.toMap());
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
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  @override
  Future<int> updateNote(Note note) async {
    return await _databaseService.updateNote(note.toMap());
  }

  @override
  Future<int> deleteNote(int id) async {
    return await _databaseService.deleteNote(id);
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    final maps = await _databaseService.searchNotes(query);
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  @override
  Future<List<Note>> getRecentNotes({int limit = 5}) async {
    final maps = await _databaseService.getRecentNotes(limit: limit);
    return maps.map((m) => Note.fromMap(m)).toList();
  }

  @override
  Future<List<Note>> getPendingTasks({int limit = 10}) async {
    final maps = await _databaseService.getPendingTasks(limit: limit);
    return maps.map((m) => Note.fromMap(m)).toList();
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
    return {
      'totalNotes': (await getAllNotes()).length,
      'totalTasks': (await getPendingTasks()).length,
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
    for (final id in noteIds) {
      await deleteNote(id);
    }
  }

  @override
  Future<List<Map<String, dynamic>>> exportAllNotes() async {
    final notes = await getAllNotes();
    return notes.map((note) => note.toJson()).toList();
  }

  @override
  Future<void> importNotes(List<Map<String, dynamic>> notesData) async {
    final notes = notesData.map((data) => Note.fromJson(data)).toList();
    await insertNotes(notes);
  }

  @override
  Future<int> addNote(Note note) async {
    return await _databaseService.insertNote(note.toMap());
  }

  @override
  Future<List<Note>> getBacklinksForNote(int noteId) async {
    final maps = await _databaseService.getBacklinksForNote(noteId);
    return maps.map((m) => Backlink.fromMap(m)).toList();
  }

  @override
  Future<List<Note>> getOutgoingLinksForNote(int noteId) async {
    final maps = await _databaseService.getOutgoingLinksForNote(noteId);
    return maps.map((m) => Backlink.fromMap(m)).toList();
  }

  @override
  Future<void> updateBacklinks(Note note, List<Note> allNotes) async {
    await _databaseService.updateBacklinks(note.id, note.content, allNotes.map((n) => n.toMap()).toList());
  }

  @override
  Future<int> getNoteCountInFolder(String folderName) async {
    return await _databaseService.getNoteCountInFolder(folderName);
  }

  @override
  Future<List<String>> getFolders() async {
    return await getAllFolders();
  }
}
