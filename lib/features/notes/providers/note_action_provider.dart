import 'package:flutter/material.dart';
import '../models/note_model.dart';
import '../services/note_service.dart';
import '../services/note_search_service.dart';
import 'note_state_provider.dart';

/// Action provider for notes - only handles business logic actions
/// Follows Single Responsibility Principle: Only handles business operations
class NoteActionProvider with ChangeNotifier {
  final NoteService _noteService;
  final NoteSearchService _searchService;
  final NoteStateProvider _stateProvider;

  NoteActionProvider(
    this._noteService,
    this._searchService,
    this._stateProvider,
  );

  // Load operations
  Future<void> loadNotes() async {
    _stateProvider.setLoading(true);
    try {
      final notes = await _noteService.getAllNotes();
      _stateProvider.setNotes(notes);
    } catch (e) {
      debugPrint('Error loading notes: $e');
      _stateProvider.setNotes([]);
    } finally {
      _stateProvider.setLoading(false);
    }
  }

  // CRUD operations
  Future<void> createNote({
    required String title,
    required String content,
    List<String> tags = const [],
    String folderName = 'Genel',
    int? color,
    bool isEncrypted = false,
  }) async {
    try {
      final note = await _noteService.createNote(
        title: title,
        content: content,
        tags: tags,
        folderName: folderName,
        color: color,
        isEncrypted: isEncrypted,
      );
      _stateProvider.addNote(note);
    } catch (e) {
      debugPrint('Error creating note: $e');
      rethrow;
    }
  }

  Future<void> updateNote(Note note) async {
    try {
      final updatedNote = await _noteService.updateNote(note);
      _stateProvider.updateNote(updatedNote);
    } catch (e) {
      debugPrint('Error updating note: $e');
      rethrow;
    }
  }

  Future<void> deleteNote(int noteId) async {
    try {
      await _noteService.deleteNote(noteId);
      _stateProvider.removeNote(noteId);
    } catch (e) {
      debugPrint('Error deleting note: $e');
      rethrow;
    }
  }

  // Search operations
  Future<void> searchNotes(String query) async {
    _stateProvider.setSearchQuery(query);
    _stateProvider.setLoading(true);
    
    try {
      if (query.isEmpty) {
        _stateProvider.setSearchResults(_stateProvider.notes);
      } else {
        final results = await _searchService.fuzzySearch(query, _stateProvider.notes);
        _stateProvider.setSearchResults(results);
      }
    } catch (e) {
      debugPrint('Search error: $e');
      _stateProvider.setSearchResults([]);
    } finally {
      _stateProvider.setLoading(false);
    }
  }

  Future<void> advancedSearch({
    String query = '',
    List<String>? tags,
    String? folder,
    DateTime? startDate,
    DateTime? endDate,
    bool? isEncrypted,
    int? minWordCount,
    int? maxWordCount,
    bool hasLinks = false,
    bool hasTasks = false,
  }) async {
    _stateProvider.setLoading(true);
    
    try {
      final results = await _searchService.advancedSearch(
        query: query,
        tags: tags,
        folder: folder,
        startDate: startDate,
        endDate: endDate,
        isEncrypted: isEncrypted,
        minWordCount: minWordCount,
        maxWordCount: maxWordCount,
        hasLinks: hasLinks,
        hasTasks: hasTasks,
      );
      _stateProvider.setSearchResults(results);
    } catch (e) {
      debugPrint('Advanced search error: $e');
      _stateProvider.setSearchResults([]);
    } finally {
      _stateProvider.setLoading(false);
    }
  }

  // Filter operations
  void filterByFolder(String folder) {
    _stateProvider.setSelectedFolder(folder);
    _applyFilters();
  }

  void filterByTags(List<String> tags) {
    _stateProvider.setSelectedTags(tags);
    _applyFilters();
  }

  void clearFilters() {
    _stateProvider.resetFilters();
    _stateProvider.clearSearch();
  }

  void _applyFilters() {
    var filteredNotes = List<Note>.from(_stateProvider.notes);

    // Apply folder filter
    if (_stateProvider.selectedFolder != 'Genel') {
      filteredNotes = filteredNotes
          .where((note) => note.folderName == _stateProvider.selectedFolder)
          .toList();
    }

    // Apply tag filters
    if (_stateProvider.selectedTags.isNotEmpty) {
      filteredNotes = filteredNotes.where((note) {
        return _stateProvider.selectedTags
            .any((tag) => note.tags.contains(tag));
      }).toList();
    }

    _stateProvider.setSearchResults(filteredNotes);
  }

  // Link operations
  Future<List<Note>> getLinkedNotes(int noteId) async {
    try {
      return await _noteService.getLinkedNotes(noteId);
    } catch (e) {
      debugPrint('Error getting linked notes: $e');
      return [];
    }
  }

  Future<List<Note>> getReferringNotes(int noteId) async {
    try {
      return await _noteService.getReferringNotes(noteId);
    } catch (e) {
      debugPrint('Error getting referring notes: $e');
      return [];
    }
  }

  Future<Map<String, dynamic>> getLinkStats(int noteId) async {
    try {
      return await _noteService.getLinkStats(noteId);
    } catch (e) {
      debugPrint('Error getting link stats: $e');
      return {};
    }
  }

  // Special operations
  Future<List<Note>> getOrphanedNotes() async {
    try {
      return await _noteService.getOrphanedNotes();
    } catch (e) {
      debugPrint('Error getting orphaned notes: $e');
      return [];
    }
  }

  Future<List<Note>> getHubNotes({int minimumLinks = 3}) async {
    try {
      return await _noteService.getHubNotes(minimumLinks: minimumLinks);
    } catch (e) {
      debugPrint('Error getting hub notes: $e');
      return [];
    }
  }

  Future<List<Note>> suggestRelatedNotes(int noteId, {int limit = 5}) async {
    try {
      return await _noteService.suggestRelatedNotes(noteId, limit: limit);
    } catch (e) {
      debugPrint('Error getting related notes: $e');
      return [];
    }
  }

  // Batch operations
  Future<void> createMultipleNotes(List<Note> notes) async {
    try {
      await _noteService.createMultipleNotes(notes);
      _stateProvider.addMultipleNotes(notes);
    } catch (e) {
      debugPrint('Error creating multiple notes: $e');
      rethrow;
    }
  }

  Future<void> deleteMultipleNotes(List<int> noteIds) async {
    try {
      for (final id in noteIds) {
        await _noteService.deleteNote(id);
      }
      _stateProvider.removeMultipleNotes(noteIds);
    } catch (e) {
      debugPrint('Error deleting multiple notes: $e');
      rethrow;
    }
  }

  // Export/Import operations
  Future<List<Map<String, dynamic>>> exportNotes() async {
    try {
      return await _noteService.exportNotes();
    } catch (e) {
      debugPrint('Error exporting notes: $e');
      rethrow;
    }
  }

  Future<void> importNotes(List<Map<String, dynamic>> notesData) async {
    try {
      await _noteService.importNotes(notesData);
      await loadNotes(); // Reload all notes
    } catch (e) {
      debugPrint('Error importing notes: $e');
      rethrow;
    }
  }

  // Statistics
  Future<Map<String, dynamic>> getDatabaseStats() async {
    try {
      return await _noteService.getDatabaseStats();
    } catch (e) {
      debugPrint('Error getting database stats: $e');
      return {};
    }
  }

  // Utility operations
  Future<List<String>> suggestTags(String content) async {
    try {
      return await _noteService.suggestTags(content);
    } catch (e) {
      debugPrint('Error suggesting tags: $e');
      return [];
    }
  }

  Future<List<String>> getSearchSuggestions(String partialQuery) async {
    try {
      return await _searchService.getSearchSuggestions(partialQuery);
    } catch (e) {
      debugPrint('Error getting search suggestions: $e');
      return [];
    }
  }

  Future<List<String>> getPopularSearchTerms() async {
    try {
      return await _searchService.getPopularSearchTerms();
    } catch (e) {
      debugPrint('Error getting popular search terms: $e');
      return [];
    }
  }

  // Note selection
  void selectNote(Note? note) {
    _stateProvider.setCurrentNote(note);
  }

  Note? getCurrentNote() {
    return _stateProvider.currentNote;
  }

  // Validation
  bool validateNote(Note note) {
    return _noteService.validateNote(note);
  }

  // Refresh operations
  Future<void> refresh() async {
    await loadNotes();
  }

  Future<void> refreshSearch() async {
    await searchNotes(_stateProvider.searchQuery);
  }
}
