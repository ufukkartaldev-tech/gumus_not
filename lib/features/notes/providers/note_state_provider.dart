import 'package:flutter/material.dart';
import '../models/note_model.dart';

/// State provider for notes - only manages state
/// Follows Single Responsibility Principle: Only handles state management
class NoteStateProvider with ChangeNotifier {
  List<Note> _notes = [];
  List<Note> _searchResults = [];
  bool _isLoading = false;
  String _searchQuery = '';
  String _selectedFolder = 'Genel';
  List<String> _selectedTags = [];
  Note? _currentNote;

  // Getters
  List<Note> get notes => List.unmodifiable(_notes);
  List<Note> get searchResults => List.unmodifiable(_searchResults);
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;
  String get selectedFolder => _selectedFolder;
  List<String> get selectedTags => List.unmodifiable(_selectedTags);
  Note? get currentNote => _currentNote;

  // Computed properties
  List<String> get folders {
    final folderSet = _notes
        .map((n) => n.folderName)
        .where((f) => f.isNotEmpty)
        .toSet();
    if (!folderSet.contains('Genel')) folderSet.add('Genel');
    final list = folderSet.toList()..sort();
    return list;
  }

  Map<String, int> get folderStats {
    final stats = <String, int>{};
    for (final note in _notes) {
      stats[note.folderName] = (stats[note.folderName] ?? 0) + 1;
    }
    return stats;
  }

  Map<String, int> get tagFrequency {
    final frequency = <String, int>{};
    for (final note in _notes) {
      for (final tag in note.tags) {
        frequency[tag] = (frequency[tag] ?? 0) + 1;
      }
    }
    return frequency;
  }

  int getNoteCountInFolder(String folderName) {
    return _notes.where((n) => n.folderName == folderName).length;
  }

  List<Note> getNotesByFolder(String folderName) {
    return _notes.where((n) => n.folderName == folderName).toList();
  }

  List<Note> getNotesByTag(String tag) {
    return _notes.where((note) => note.tags.contains(tag)).toList();
  }

  // State setters
  void setNotes(List<Note> notes) {
    _notes = notes;
    _searchResults = _searchQuery.isEmpty ? notes : _searchResults;
    notifyListeners();
  }

  void setSearchResults(List<Note> results) {
    _searchResults = results;
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setSelectedFolder(String folder) {
    _selectedFolder = folder;
    notifyListeners();
  }

  void setSelectedTags(List<String> tags) {
    _selectedTags = tags;
    notifyListeners();
  }

  void setCurrentNote(Note? note) {
    _currentNote = note;
    notifyListeners();
  }

  void addNote(Note note) {
    _notes.insert(0, note);
    if (_searchQuery.isEmpty) {
      _searchResults.insert(0, note);
    }
    notifyListeners();
  }

  void updateNote(Note note) {
    final index = _notes.indexWhere((n) => n.id == note.id);
    if (index != -1) {
      _notes[index] = note;
    }
    
    final searchIndex = _searchResults.indexWhere((n) => n.id == note.id);
    if (searchIndex != -1) {
      _searchResults[searchIndex] = note;
    }
    
    if (_currentNote?.id == note.id) {
      _currentNote = note;
    }
    
    notifyListeners();
  }

  void removeNote(int noteId) {
    _notes.removeWhere((note) => note.id == noteId);
    _searchResults.removeWhere((note) => note.id == noteId);
    
    if (_currentNote?.id == noteId) {
      _currentNote = null;
    }
    
    notifyListeners();
  }

  void clearSearch() {
    _searchQuery = '';
    _searchResults = _notes;
    notifyListeners();
  }

  void resetFilters() {
    _selectedFolder = 'Genel';
    _selectedTags = [];
    notifyListeners();
  }

  void refreshSearchResults() {
    // This would typically trigger a new search
    notifyListeners();
  }

  // Batch operations
  void addMultipleNotes(List<Note> notes) {
    _notes.insertAll(0, notes);
    if (_searchQuery.isEmpty) {
      _searchResults.insertAll(0, notes);
    }
    notifyListeners();
  }

  void removeMultipleNotes(List<int> noteIds) {
    _notes.removeWhere((note) => noteIds.contains(note.id));
    _searchResults.removeWhere((note) => noteIds.contains(note.id));
    
    if (_currentNote != null && noteIds.contains(_currentNote!.id)) {
      _currentNote = null;
    }
    
    notifyListeners();
  }

  // Utility methods
  void clearAll() {
    _notes.clear();
    _searchResults.clear();
    _searchQuery = '';
    _selectedFolder = 'Genel';
    _selectedTags.clear();
    _currentNote = null;
    _isLoading = false;
    notifyListeners();
  }

  Note? getNoteById(int id) {
    try {
      return _notes.firstWhere((note) => note.id == id);
    } catch (e) {
      return null;
    }
  }

  bool hasNote(int id) {
    return _notes.any((note) => note.id == id);
  }

  int get totalNotes => _notes.length;
  int get totalSearchResults => _searchResults.length;
  int get totalTags => tagFrequency.length;
  int get totalFolders => folders.length;
}
