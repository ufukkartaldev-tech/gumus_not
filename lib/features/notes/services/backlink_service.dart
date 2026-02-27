import '../models/note_model.dart';
import '../repositories/inote_repository.dart';

/// Service for managing backlinks between notes
/// Follows Single Responsibility Principle: Only handles note linking operations
class BacklinkService {
  final INoteRepository _repository;

  BacklinkService(this._repository);

  /// Update all backlinks for a note when its content changes
  Future<void> updateBacklinks(int? noteId, String content) async {
    if (noteId == null) return;
    
    final allNotes = await _repository.getAllNotes();
    await _updateBacklinksInternal(noteId, content, allNotes);
  }

  /// Get all notes that link to the specified note
  Future<List<Note>> getReferringNotes(int noteId) async {
    final allNotes = await _repository.getAllNotes();
    final referringNotes = <Note>[];
    
    for (final note in allNotes) {
      final links = note.extractLinks();
      final targetNote = allNotes.firstWhere(
        (n) => n.title.toLowerCase() == links.firstWhere(
          (link) => allNotes.any((n) => n.title.toLowerCase() == link.toLowerCase()),
          orElse: () => '',
        ).toLowerCase(),
        orElse: () => Note(
          id: -1,
          title: '',
          content: '',
          createdAt: 0,
          updatedAt: 0,
        ),
      );
      
      if (targetNote.id == noteId) {
        referringNotes.add(note);
      }
    }
    
    return referringNotes;
  }

  /// Get all notes that the specified note links to
  Future<List<Note>> getLinkedNotes(int noteId) async {
    final note = await _repository.getNoteById(noteId);
    if (note == null) return [];
    
    final allNotes = await _repository.getAllNotes();
    final linkedNotes = <Note>[];
    final links = note.extractLinks();
    
    for (final link in links) {
      final targetNote = allNotes.firstWhere(
        (n) => n.title.toLowerCase() == link.toLowerCase(),
        orElse: () => Note(
          id: -1,
          title: link,
          content: '',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      
      if (targetNote.id != -1) {
        linkedNotes.add(targetNote);
      }
    }
    
    return linkedNotes;
  }

  /// Find orphaned notes (notes with no incoming links)
  Future<List<Note>> getOrphanedNotes() async {
    final allNotes = await _repository.getAllNotes();
    final orphanedNotes = <Note>[];
    
    for (final note in allNotes) {
      final referringNotes = await getReferringNotes(note.id!);
      if (referringNotes.isEmpty) {
        orphanedNotes.add(note);
      }
    }
    
    return orphanedNotes;
  }

  /// Find hub notes (notes with many outgoing links)
  Future<List<Note>> getHubNotes({int minimumLinks = 3}) async {
    final allNotes = await _repository.getAllNotes();
    final hubNotes = <Note>[];
    
    for (final note in allNotes) {
      final linkedNotes = await getLinkedNotes(note.id!);
      if (linkedNotes.length >= minimumLinks) {
        hubNotes.add(note);
      }
    }
    
    // Sort by number of outgoing links (descending)
    hubNotes.sort((a, b) async {
      final aLinks = await getLinkedNotes(a.id!);
      final bLinks = await getLinkedNotes(b.id!);
      return bLinks.length.compareTo(aLinks.length);
    });
    
    return hubNotes;
  }

  /// Get link statistics for a note
  Future<Map<String, dynamic>> getLinkStats(int noteId) async {
    final linkedNotes = await getLinkedNotes(noteId);
    final referringNotes = await getReferringNotes(noteId);
    
    return {
      'outgoingLinks': linkedNotes.length,
      'incomingLinks': referringNotes.length,
      'totalLinks': linkedNotes.length + referringNotes.length,
      'linkedNotes': linkedNotes,
      'referringNotes': referringNotes,
    };
  }

  /// Internal method to update backlinks (mirrors DatabaseService.updateBacklinks)
  Future<void> _updateBacklinksInternal(int noteId, String content, List<Note> allNotes) async {
    // This would typically involve database operations
    // For now, we'll simulate the backlink update logic
    final RegExp linkRegex = RegExp(r'\[\[([^\]]+)\]\]');
    final matches = linkRegex.allMatches(content);
    
    for (final match in matches) {
      final linkText = match.group(1)!;
      
      final targetNote = allNotes.firstWhere(
        (note) => note.title.toLowerCase() == linkText.toLowerCase(),
        orElse: () => Note(
          id: -1,
          title: linkText,
          content: '',
          createdAt: DateTime.now().millisecondsSinceEpoch,
          updatedAt: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      
      // In a real implementation, this would update the backlinks table
      // For now, we'll just log the operation
      print('Backlink: ${noteId} -> ${targetNote.id} ($linkText)');
    }
  }

  /// Suggest related notes based on link patterns
  Future<List<Note>> suggestRelatedNotes(int noteId, {int limit = 5}) async {
    final note = await _repository.getNoteById(noteId);
    if (note == null) return [];
    
    final allNotes = await _repository.getAllNotes();
    final suggestions = <Note>[];
    
    // Find notes with similar tags
    for (final otherNote in allNotes) {
      if (otherNote.id == noteId) continue;
      
      final commonTags = note.tags.where((tag) => otherNote.tags.contains(tag));
      if (commonTags.isNotEmpty) {
        suggestions.add(otherNote);
      }
    }
    
    // Find notes that link to similar targets
    final linkedNotes = await getLinkedNotes(noteId);
    for (final otherNote in allNotes) {
      if (otherNote.id == noteId || suggestions.contains(otherNote)) continue;
      
      final otherLinkedNotes = await getLinkedNotes(otherNote.id!);
      final commonLinks = linkedNotes.where((link) => otherLinkedNotes.contains(link));
      
      if (commonLinks.isNotEmpty) {
        suggestions.add(otherNote);
      }
    }
    
    return suggestions.take(limit).toList();
  }
}
