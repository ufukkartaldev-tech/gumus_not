import 'package:connected_notebook/features/notes/models/note_model.dart';

/// Abstract interface for search operations
/// Separates search logic from state management
abstract class SearchService {
  /// Search notes with fuzzy matching and semantic analysis
  Future<List<Note>> searchNotes(String query, List<Note> allNotes);
  
  /// Get linked notes for a specific note
  Future<List<Note>> getLinkedNotes(int noteId, List<Note> allNotes);
  
  /// Get notes that refer to a specific note
  Future<List<Note>> getReferringNotes(int noteId, List<Note> allNotes);
}