import 'package:flutter/material.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/repositories/note_repository.dart';
import 'package:connected_notebook/features/notes/services/search_service_interface.dart';

/// State management provider for notes
/// Follows Single Responsibility Principle: Only manages UI state
/// Business logic is delegated to repository and services
class NoteProvider with ChangeNotifier {
  // Dependencies injected via constructor
  final NoteRepository _repository;
  final SearchService _searchService;
  
  // State
  List<Note> _notes = [];
  List<Note> _searchResults = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String? _selectedFolder;
  String? _selectedTag;
  
  // Getters
  List<Note> get notes => _notes;
  List<Note> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String? get selectedFolder => _selectedFolder;
  String? get selectedTag => _selectedTag;
  
  // Computed properties
  List<String> get folders {
    final folderSet = _notes.map((n) => n.folderName).where((f) => f.isNotEmpty).toSet();
    if (!folderSet.contains('Genel')) folderSet.add('Genel');
    final list = folderSet.toList()..sort();
    return list;
  }
  
  int getNoteCountInFolder(String folderName) {
    return _notes.where((n) => n.folderName == folderName).length;
  }
  
  Map<String, int> get tagFrequency {
    final Map<String, int> frequency = {};
    for (final note in _notes) {
      for (final tag in note.tags) {
        frequency[tag] = (frequency[tag] ?? 0) + 1;
      }
    }
    return frequency;
  }
  
  /// Constructor with dependency injection
  NoteProvider({
    required NoteRepository repository,
    required SearchService searchService,
  }) : _repository = repository, _searchService = searchService;
  
  /// Load all notes from repository
  Future<void> loadNotes() async {
    _setLoading(true);
    
    try {
      _notes = await _repository.getAllNotes();
      _searchResults = _notes;
      _notifyOnce(); // Single notification after all state changes
    } catch (e) {
      debugPrint('Error loading notes: $e');
      _notes = [];
      _searchResults = [];
      _notifyOnce();
    } finally {
      _setLoading(false);
    }
  }
  
  /// Add a new note
  Future<void> addNote(Note note) async {
    try {
      final id = await _repository.addNote(note);
      final newNote = note.copyWith(id: id);
      
      // Update backlinks
      await _repository.updateBacklinks(newNote, _notes);
      
      // Update local state
      _notes.insert(0, newNote);
      await _performSearch(_searchQuery); // Update search results
      _notifyOnce();
    } catch (e) {
      debugPrint('Error adding note: $e');
      rethrow;
    }
  }
  
  /// Update an existing note
  Future<void> updateNote(Note note) async {
    try {
      await _repository.updateNote(note);
      
      // Update backlinks
      await _repository.updateBacklinks(note, _notes);
      
      // Update local state
      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _notes[index] = note;
      }
      
      await _performSearch(_searchQuery); // Update search results
      _notifyOnce();
    } catch (e) {
      debugPrint('Error updating note: $e');
      rethrow;
    }
  }
  
  /// Delete a note by ID
  Future<void> deleteNote(int noteId) async {
    try {
      await _repository.deleteNote(noteId);
      
      // Update local state
      _notes.removeWhere((note) => note.id == noteId);
      await _performSearch(_searchQuery); // Update search results
      _notifyOnce();
    } catch (e) {
      debugPrint('Error deleting note: $e');
      rethrow;
    }
  }
  
  /// Search notes with query
  Future<void> searchNotes(String query) async {
    _searchQuery = query;
    _setLoading(true);
    
    try {
      await _performSearch(query);
    } catch (e) {
      debugPrint('Search error: $e');
      _searchResults = [];
      _notifyOnce();
    } finally {
      _setLoading(false);
    }
  }
  
  /// Filter notes by folder
  Future<void> filterByFolder(String? folderName) async {
    _selectedFolder = folderName;
    _selectedTag = null; // Clear tag filter
    
    if (folderName == null) {
      _searchResults = _notes;
    } else {
      _searchResults = _notes.where((n) => n.folderName == folderName).toList();
    }
    
    _notifyOnce();
  }
  
  /// Filter notes by tag
  Future<void> filterByTag(String? tag) async {
    _selectedTag = tag;
    _selectedFolder = null; // Clear folder filter
    
    if (tag == null) {
      _searchResults = _notes;
    } else {
      _searchResults = _notes.where((n) => n.tags.contains(tag)).toList();
    }
    
    _notifyOnce();
  }
  
  /// Clear all filters
  Future<void> clearFilters() async {
    _selectedFolder = null;
    _selectedTag = null;
    _searchQuery = '';
    _searchResults = _notes;
    _notifyOnce();
  }
  
  /// Get a note by ID (from local cache)
  Note? getNoteById(int id) {
    try {
      return _notes.firstWhere((note) => note.id == id);
    } catch (e) {
      return null;
    }
  }
  
  /// Get notes by tag (from local cache)
  List<Note> getNotesByTag(String tag) {
    return _notes.where((note) => note.tags.contains(tag)).toList();
  }
  
  /// Get linked notes (notes that this note links to)
  Future<List<Note>> getLinkedNotes(int noteId) async {
    return await _searchService.getLinkedNotes(noteId, _notes);
  }
  
  /// Get referring notes (notes that link to this note)
  Future<List<Note>> getReferringNotes(int noteId) async {
    return await _searchService.getReferringNotes(noteId, _notes);
  }
  
  /// Get database statistics
  Future<Map<String, dynamic>> getDatabaseStats() async {
    return await _repository.getDatabaseStats();
  }
  
  /// Get recent notes
  Future<List<Note>> getRecentNotes({int limit = 5}) async {
    return await _repository.getRecentNotes(limit: limit);
  }
  
  /// Get pending tasks
  Future<List<Note>> getPendingTasks({int limit = 10}) async {
    return await _repository.getPendingTasks(limit: limit);
  }
  
  // Private helper methods
  
  Future<void> _performSearch(String query) async {
    if (query.isEmpty) {
      // Apply folder/tag filters if any
      if (_selectedFolder != null) {
        _searchResults = _notes.where((n) => n.folderName == _selectedFolder).toList();
      } else if (_selectedTag != null) {
        _searchResults = _notes.where((n) => n.tags.contains(_selectedTag!)).toList();
      } else {
        _searchResults = _notes;
      }
    } else {
      // Use search service for complex queries
      _searchResults = await _searchService.searchNotes(query, _notes);
      
      // Apply additional filters if any
      if (_selectedFolder != null) {
        _searchResults = _searchResults.where((n) => n.folderName == _selectedFolder).toList();
      } else if (_selectedTag != null) {
        _searchResults = _searchResults.where((n) => n.tags.contains(_selectedTag!)).toList();
      }
    }
  }
  
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      // Don't notify here - will be notified with other state changes
    }
  }
  
  void _notifyOnce() {
    // Debounce notifications to prevent multiple rebuilds
    WidgetsBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }
  
  /// Clear all state (for testing or logout)
  void clear() {
    _notes = [];
    _searchResults = [];
    _isLoading = false;
    _searchQuery = '';
    _selectedFolder = null;
    _selectedTag = null;
    _notifyOnce();
  }
}