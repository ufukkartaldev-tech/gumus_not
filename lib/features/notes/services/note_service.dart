import '../models/note_model.dart';
import '../repositories/inote_repository.dart';
import 'backlink_service.dart';

/// Main service for note operations
/// Follows Single Responsibility Principle: Orchestrates note-related operations
class NoteService {
  final INoteRepository _repository;
  final BacklinkService _backlinkService;

  NoteService(this._repository, this._backlinkService);

  /// Create a new note with proper backlink processing
  Future<Note> createNote({
    required String title,
    required String content,
    List<String> tags = const [],
    String folderName = 'Genel',
    int? color,
    bool isEncrypted = false,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final note = Note(
      title: title,
      content: content,
      tags: tags,
      folderName: folderName,
      color: color,
      isEncrypted: isEncrypted,
      createdAt: now,
      updatedAt: now,
    );

    final id = await _repository.insertNote(note);
    final createdNote = note.copyWith(id: id);

    // Update backlinks for this note
    await _backlinkService.updateBacklinks(id, content);

    return createdNote;
  }

  /// Update an existing note with backlink processing
  Future<Note> updateNote(Note note) async {
    final updatedNote = note.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );

    await _repository.updateNote(updatedNote);

    // Update backlinks since content might have changed
    await _backlinkService.updateBacklinks(note.id, updatedNote.content);

    return updatedNote;
  }

  /// Delete a note and clean up its backlinks
  Future<void> deleteNote(int noteId) async {
    // In a full implementation, we would also clean up backlinks
    // For now, just delete the note
    await _repository.deleteNote(noteId);
  }

  /// Get a note by ID
  Future<Note?> getNoteById(int id) async {
    return await _repository.getNoteById(id);
  }

  /// Get all notes
  Future<List<Note>> getAllNotes() async {
    return await _repository.getAllNotes();
  }

  /// Get notes in a specific folder
  Future<List<Note>> getNotesByFolder(String folderName) async {
    return await _repository.getNotesByFolder(folderName);
  }

  /// Get notes with specific tag
  Future<List<Note>> getNotesByTag(String tag) async {
    return await _repository.getNotesByTag(tag);
  }

  /// Get all available folders
  Future<List<String>> getAllFolders() async {
    return await _repository.getAllFolders();
  }

  /// Get recent notes
  Future<List<Note>> getRecentNotes({int limit = 5}) async {
    return await _repository.getRecentNotes(limit: limit);
  }

  /// Get pending tasks
  Future<List<Note>> getPendingTasks({int limit = 10}) async {
    return await _repository.getPendingTasks(limit: limit);
  }

  /// Get tag frequency statistics
  Future<Map<String, int>> getTagFrequency() async {
    final allNotes = await _repository.getAllNotes();
    final tagFrequency = <String, int>{};

    for (final note in allNotes) {
      for (final tag in note.tags) {
        tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
      }
    }

    return tagFrequency;
  }

  /// Get folder statistics
  Future<Map<String, int>> getFolderStats() async {
    final allNotes = await _repository.getAllNotes();
    final folderStats = <String, int>{};

    for (final note in allNotes) {
      folderStats[note.folderName] = (folderStats[note.folderName] ?? 0) + 1;
    }

    return folderStats;
  }

  /// Get notes linked to a specific note
  Future<List<Note>> getLinkedNotes(int noteId) async {
    return await _backlinkService.getLinkedNotes(noteId);
  }

  /// Get notes that refer to a specific note
  Future<List<Note>> getReferringNotes(int noteId) async {
    return await _backlinkService.getReferringNotes(noteId);
  }

  /// Get link statistics for a note
  Future<Map<String, dynamic>> getLinkStats(int noteId) async {
    return await _backlinkService.getLinkStats(noteId);
  }

  /// Find orphaned notes
  Future<List<Note>> getOrphanedNotes() async {
    return await _backlinkService.getOrphanedNotes();
  }

  /// Find hub notes
  Future<List<Note>> getHubNotes({int minimumLinks = 3}) async {
    return await _backlinkService.getHubNotes(minimumLinks: minimumLinks);
  }

  /// Suggest related notes
  Future<List<Note>> suggestRelatedNotes(int noteId, {int limit = 5}) async {
    return await _backlinkService.suggestRelatedNotes(noteId, limit: limit);
  }

  /// Batch operations
  Future<void> createMultipleNotes(List<Note> notes) async {
    await _repository.insertNotes(notes);
    
    // Update backlinks for all created notes
    for (final note in notes) {
      if (note.id != null) {
        await _backlinkService.updateBacklinks(note.id, note.content);
      }
    }
  }

  Future<void> deleteMultipleNotes(List<int> noteIds) async {
    for (final id in noteIds) {
      await deleteNote(id);
    }
  }

  /// Export/Import operations
  Future<List<Map<String, dynamic>>> exportNotes() async {
    return await _repository.exportAllNotes();
  }

  Future<void> importNotes(List<Map<String, dynamic>> notesData) async {
    await _repository.importNotes(notesData);
  }

  /// Search operations (delegated to SearchService)
  Future<List<Note>> searchNotes(String query) async {
    return await _repository.searchNotes(query);
  }

  /// Get database statistics
  Future<Map<String, dynamic>> getDatabaseStats() async {
    final stats = await _repository.getDatabaseStats();
    final tagFrequency = await getTagFrequency();
    final folderStats = await getFolderStats();
    
    return {
      ...stats,
      'tagFrequency': tagFrequency,
      'folderStats': folderStats,
      'totalTags': tagFrequency.length,
      'totalFolders': folderStats.length,
    };
  }

  /// Validate note data
  bool validateNote(Note note) {
    if (note.title.trim().isEmpty) return false;
    if (note.content.trim().isEmpty) return false;
    if (note.title.length > 200) return false; // Reasonable limit
    if (note.content.length > 1000000) return false; // 1MB limit
    
    return true;
  }

  /// Auto-tag suggestions based on content
  Future<List<String>> suggestTags(String content) async {
    final allNotes = await _repository.getAllNotes();
    final contentLower = content.toLowerCase();
    final suggestions = <String>{};

    // Extract common words from existing notes
    final allTags = <String>{};
    for (final note in allNotes) {
      allTags.addAll(note.tags);
    }

    // Simple keyword matching (could be enhanced with NLP)
    for (final tag in allTags) {
      if (contentLower.contains(tag.toLowerCase())) {
        suggestions.add(tag);
      }
    }

    return suggestions.toList();
  }
}
