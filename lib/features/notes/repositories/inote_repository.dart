import '../models/note_model.dart';

/// Abstract repository interface for Note operations
/// Following SOLID principles: Interface Segregation and Dependency Inversion
abstract class INoteRepository {
  /// CRUD Operations
  Future<int> insertNote(Note note);
  Future<Note?> getNoteById(int id);
  Future<List<Note>> getAllNotes();
  Future<int> updateNote(Note note);
  Future<int> deleteNote(int id);
  
  /// Search Operations
  Future<List<Note>> searchNotes(String query);
  Future<List<Note>> getRecentNotes({int limit = 5});
  Future<List<Note>> getPendingTasks({int limit = 10});
  
  /// Filter Operations
  Future<List<Note>> getNotesByFolder(String folderName);
  Future<List<Note>> getNotesByTag(String tag);
  Future<List<String>> getAllFolders();
  
  /// Statistics
  Future<Map<String, dynamic>> getDatabaseStats();
  
  /// Batch Operations
  Future<void> insertNotes(List<Note> notes);
  Future<void> deleteNotes(List<int> noteIds);
  
  /// Backup/Export
  Future<List<Map<String, dynamic>>> exportAllNotes();
  Future<void> importNotes(List<Map<String, dynamic>> notesData);
}
