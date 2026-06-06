import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/services/search_service_interface.dart';
import 'package:connected_notebook/features/notes/repositories/note_repository.dart';

/// Advanced search service using FTS5 for high performance
/// Implements the SearchService interface
class AdvancedSearchService implements SearchService {
  final NoteRepository _repository;

  AdvancedSearchService(this._repository);
  
  @override
  Future<List<Note>> searchNotes(String query, [List<Note>? allNotes]) async {
    if (query.trim().isEmpty) return allNotes ?? [];
    
    // FTS5 prefix search
    final formattedQuery = '${query.trim()}*';
    
    // Use repository's optimized FTS5 search
    return await _repository.searchNotes(formattedQuery);
  }
  
  @override
  Future<List<Note>> getLinkedNotes(int noteId, List<Note> allNotes) async {
    final note = allNotes.firstWhere((n) => n.id == noteId, orElse: () => Note(
      title: '', 
      content: '', 
      createdAt: 0, 
      updatedAt: 0
    ));
    if (note.id == null) return [];
    
    final linkedNoteTitles = note.extractLinks();
    final linkedNotes = <Note>[];
    
    for (final linkText in linkedNoteTitles) {
      final targetNote = allNotes.firstWhere(
        (n) => n.title.toLowerCase() == linkText.toLowerCase(),
        orElse: () => Note(title: '', content: '', createdAt: 0, updatedAt: 0),
      );
      
      if (targetNote.id != null) {
        linkedNotes.add(targetNote);
      }
    }
    
    return linkedNotes;
  }
  
  @override
  Future<List<Note>> getReferringNotes(int noteId, List<Note> allNotes) async {
    final note = allNotes.firstWhere((n) => n.id == noteId, orElse: () => Note(
      title: '', 
      content: '', 
      createdAt: 0, 
      updatedAt: 0
    ));
    if (note.id == null) return [];
    
    final referringNotes = <Note>[];
    final targetTitle = note.title.toLowerCase();
    
    for (final otherNote in allNotes) {
      if (otherNote.id == noteId) continue;
      
      final links = otherNote.extractLinks();
      if (links.any((link) => link.toLowerCase() == targetTitle)) {
        referringNotes.add(otherNote);
      }
    }
    
    return referringNotes;
  }
}