import '../models/note_model.dart';
import '../repositories/note_repository.dart';

/// Service for managing backlinks between notes
/// Follows Single Responsibility Principle: Only handles note linking operations
class BacklinkService {
  final NoteRepository _repository;

  BacklinkService(this._repository);

  /// Update all backlinks for a note when its content changes
  Future<void> updateBacklinks(int? noteId, String content) async {
    if (noteId == null) return;

    final allNotes = await _repository.getAllNotes();
    await _updateBacklinksInternal(noteId, content, allNotes);
  }

  /// Get all notes that link to the specified note (`O(N)` single pass)
  Future<List<Note>> getReferringNotes(int noteId) async {
    final allNotes = await _repository.getAllNotes();
    final target = allNotes.where((n) => n.id == noteId).firstOrNull;
    if (target == null) return [];

    final targetTitleLower = target.title.trim().toLowerCase();
    if (targetTitleLower.isEmpty) return [];

    final referringNotes = <Note>[];
    for (final note in allNotes) {
      if (note.id == noteId || note.isEncrypted) continue;
      final links = note.extractLinks();
      if (links.any((link) => link.trim().toLowerCase() == targetTitleLower)) {
        referringNotes.add(note);
      }
    }

    return referringNotes;
  }

  /// Get all notes that the specified note links to (`O(N)` with title index map)
  Future<List<Note>> getLinkedNotes(int noteId) async {
    final note = await _repository.getNoteById(noteId);
    if (note == null || note.isEncrypted) return [];

    final allNotes = await _repository.getAllNotes();
    final byTitle = <String, Note>{
      for (final n in allNotes) n.title.trim().toLowerCase(): n,
    };

    final linkedNotes = <Note>[];
    final seenIds = <int>{};
    for (final link in note.extractLinks()) {
      final targetNote = byTitle[link.trim().toLowerCase()];
      if (targetNote != null &&
          targetNote.id != null &&
          targetNote.id != noteId &&
          seenIds.add(targetNote.id!)) {
        linkedNotes.add(targetNote);
      }
    }

    return linkedNotes;
  }

  /// Find orphaned notes (notes with no incoming links) in a single `O(N)` pass
  Future<List<Note>> getOrphanedNotes() async {
    final allNotes = await _repository.getAllNotes();
    final referencedTitles = <String>{};

    for (final note in allNotes) {
      if (note.isEncrypted) continue;
      for (final link in note.extractLinks()) {
        referencedTitles.add(link.trim().toLowerCase());
      }
    }

    return allNotes
        .where((n) =>
            n.id != null &&
            !referencedTitles.contains(n.title.trim().toLowerCase()))
        .toList();
  }

  /// Find hub notes (notes with many outgoing links) in a single `O(N)` pass
  Future<List<Note>> getHubNotes({int minimumLinks = 3}) async {
    final allNotes = await _repository.getAllNotes();
    final existingTitles = <String>{
      for (final n in allNotes) n.title.trim().toLowerCase(),
    };

    final hubNotes = <Note>[];
    final linkCounts = <int, int>{};

    for (final note in allNotes) {
      final id = note.id;
      if (id == null || note.isEncrypted) continue;
      final validOutgoingCount = note
          .extractLinks()
          .map((l) => l.trim().toLowerCase())
          .where((l) => l != note.title.trim().toLowerCase() && existingTitles.contains(l))
          .toSet()
          .length;

      if (validOutgoingCount >= minimumLinks) {
        hubNotes.add(note);
        linkCounts[id] = validOutgoingCount;
      }
    }

    hubNotes.sort(
      (a, b) => (linkCounts[b.id] ?? 0).compareTo(linkCounts[a.id] ?? 0),
    );

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
      final linkText = match.group(1);
      if (linkText == null) continue;

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
      print('Backlink: $noteId -> ${targetNote.id} ($linkText)');
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
      final otherId = otherNote.id;
      if (otherId == null || otherId == noteId || suggestions.contains(otherNote)) continue;

      final otherLinkedNotes = await getLinkedNotes(otherId);
      final commonLinks = linkedNotes.where((link) => otherLinkedNotes.contains(link));

      if (commonLinks.isNotEmpty) {
        suggestions.add(otherNote);
      }
    }

    return suggestions.take(limit).toList();
  }
}
