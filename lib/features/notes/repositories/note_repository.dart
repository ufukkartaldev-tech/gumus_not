import 'package:connected_notebook/features/notes/models/note_model.dart';

/// Abstract repository interface for note operations
/// Follows Dependency Inversion Principle: High-level modules depend on abstractions
abstract class NoteRepository {
  /// Get all notes sorted by update date (newest first)
  Future<List<Note>> getAllNotes();
  
  /// Get a note by its ID
  Future<Note?> getNoteById(int id);
  
  /// Search notes by query (title or content)
  Future<List<Note>> searchNotes(String query);
  
  /// Add a new note
  Future<int> addNote(Note note);
  
  /// Update an existing note
  Future<void> updateNote(Note note);
  
  /// Delete a note by ID
  Future<void> deleteNote(int id); 
  
  /// Get recent notes with limit
  Future<List<Note>> getRecentNotes({int limit = 5});
  
  /// Get notes with pending tasks
  Future<List<Note>> getPendingTasks({int limit = 10});
  
  /// Get database statistics
  Future<Map<String, dynamic>> getDatabaseStats();
  
  /// Get backlinks for a note (notes that link to this note)
  Future<List<Backlink>> getBacklinksForNote(int noteId);
  
  /// Get outgoing links from a note (notes that this note links to)
  Future<List<Backlink>> getOutgoingLinksForNote(int noteId);
  
  /// Update backlinks for a note based on its content
  Future<void> updateBacklinks(Note note, List<Note> allNotes);
  
  /// Get all folders/categories
  Future<List<String>> getFolders();
  
  /// Get note count in a specific folder
  Future<int> getNoteCountInFolder(String folderName);
  
  /// Get notes by tag
  Future<List<Note>> getNotesByTag(String tag);
  
  /// Get tag frequency statistics
  Future<Map<String, int>> getTagFrequency();
}