import 'package:flutter/material.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/core/database/database_service.dart';
import 'package:connected_notebook/features/search/services/search_service.dart';

class NoteProvider with ChangeNotifier {
  List<Note> _notes = [];
  List<Note> _searchResults = [];
  bool _isLoading = false;
  String _searchQuery = '';

  List<Note> get notes => _notes;
  List<Note> get searchResults => _searchResults;
  bool get isLoading => _isLoading;
  String get searchQuery => _searchQuery;

  List<String> get folders {
    final folderSet = _notes.map((n) => n.folderName).where((f) => f.isNotEmpty).toSet();
    if (!folderSet.contains('Genel')) folderSet.add('Genel');
    final list = folderSet.toList()..sort();
    return list;
  }

  int getNoteCountInFolder(String folderName) {
    return _notes.where((n) => n.folderName == folderName).length;
  }

  Future<void> loadNotes() async {
    _isLoading = true;
    notifyListeners();
    
    try {
      _notes = await DatabaseService.getAllNotes();
      _searchResults = _notes;
    } catch (e) {
      debugPrint('Error loading notes: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> addNote(Note note) async {
    try {
      final id = await DatabaseService.insertNote(note);
      note = note.copyWith(id: id);
      _notes.insert(0, note);
      
      await DatabaseService.updateBacklinks(id, note.content, _notes);
      
      await searchNotes(_searchQuery);
      notifyListeners();
    } catch (e) {
      debugPrint('Error adding note: $e');
    }
  }

  Future<void> updateNote(Note note) async {
    try {
      await DatabaseService.updateNote(note);
      
      final index = _notes.indexWhere((n) => n.id == note.id);
      if (index != -1) {
        _notes[index] = note;
      }
      
      await DatabaseService.updateBacklinks(note.id!, note.content, _notes);
      
      await searchNotes(_searchQuery);
      notifyListeners();
    } catch (e) {
      debugPrint('Error updating note: $e');
    }
  }

  Future<void> deleteNote(int noteId) async {
    try {
      await DatabaseService.deleteNote(noteId);
      _notes.removeWhere((note) => note.id == noteId);
      
      await searchNotes(_searchQuery);
      notifyListeners();
    } catch (e) {
      debugPrint('Error deleting note: $e');
    }
  }

  Future<void> searchNotes(String query) async {
    _searchQuery = query;
    _isLoading = true;
    notifyListeners();
    
    try {
      if (query.isEmpty) {
        _searchResults = _notes;
      } else {
        // Use the new Dart-based Fuzzy & Weighted Search
        // We pass local _notes because we want to search within current data
        // For very large datasets, we might need a different strategy, but for thousands of text notes, this is fast.
        _searchResults = await SearchService.searchNotes(query, _notes);
      }
    } catch (e) {
      debugPrint('Search error: $e');
      _searchResults = [];
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<Backlink>> getBacklinksForNote(int noteId) async {
    return await DatabaseService.getBacklinksForNote(noteId);
  }

  Future<List<Backlink>> getOutgoingLinksForNote(int noteId) async {
    return await DatabaseService.getOutgoingLinksForNote(noteId);
  }

  Note? getNoteById(int id) {
    try {
      return _notes.firstWhere((note) => note.id == id);
    } catch (e) {
      return null;
    }
  }

  List<Note> getNotesByTag(String tag) {
    return _notes.where((note) => note.tags.contains(tag)).toList();
  }

  Map<String, int> getTagFrequency() {
    final Map<String, int> tagFrequency = {};
    for (final note in _notes) {
      for (final tag in note.tags) {
        tagFrequency[tag] = (tagFrequency[tag] ?? 0) + 1;
      }
    }
    return tagFrequency;
  }

  Future<List<Note>> getLinkedNotes(int noteId) async {
    final backlinks = await DatabaseService.getOutgoingLinksForNote(noteId);
    final linkedNotes = <Note>[];
    
    for (final backlink in backlinks) {
      final note = getNoteById(backlink.targetNoteId);
      if (note != null) {
        linkedNotes.add(note);
      }
    }
    
    return linkedNotes;
  }

  Future<List<Note>> getReferringNotes(int noteId) async {
    final backlinks = await DatabaseService.getBacklinksForNote(noteId);
    final referringNotes = <Note>[];
    
    for (final backlink in backlinks) {
      final note = getNoteById(backlink.sourceNoteId);
      if (note != null) {
        referringNotes.add(note);
      }
    }
    
    return referringNotes;
  }
}
