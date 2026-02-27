import '../models/note_model.dart';
import '../../../core/database/database_service.dart';

/// Concrete implementation of INoteRepository using SQLite
/// Follows Single Responsibility Principle: Only handles note data operations
class SqlNoteRepository implements INoteRepository {
  
  @override
  Future<int> insertNote(Note note) async {
    return await DatabaseService.insertNote(note);
  }

  @override
  Future<Note?> getNoteById(int id) async {
    return await DatabaseService.getNoteById(id);
  }

  @override
  Future<List<Note>> getAllNotes() async {
    return await DatabaseService.getAllNotes();
  }

  @override
  Future<int> updateNote(Note note) async {
    return await DatabaseService.updateNote(note);
  }

  @override
  Future<int> deleteNote(int id) async {
    return await DatabaseService.deleteNote(id);
  }

  @override
  Future<List<Note>> searchNotes(String query) async {
    return await DatabaseService.searchNotes(query);
  }

  @override
  Future<List<Note>> getRecentNotes({int limit = 5}) async {
    return await DatabaseService.getRecentNotes(limit: limit);
  }

  @override
  Future<List<Note>> getPendingTasks({int limit = 10}) async {
    return await DatabaseService.getPendingTasks(limit: limit);
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
    return await DatabaseService.getDatabaseStats();
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
}
