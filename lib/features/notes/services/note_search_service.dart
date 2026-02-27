import '../models/note_model.dart';
import '../repositories/inote_repository.dart';
import 'backlink_service.dart';

/// Service for advanced note search operations
/// Follows Single Responsibility Principle: Only handles search and filtering logic
class SearchService {
  final INoteRepository _repository;
  final BacklinkService _backlinkService;

  SearchService(this._repository, this._backlinkService);

  /// Advanced search with multiple criteria
  Future<List<Note>> advancedSearch({
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
    final allNotes = await _repository.getAllNotes();
    var results = List<Note>.from(allNotes);

    // Text search
    if (query.isNotEmpty) {
      results = await fuzzySearch(query, results);
    }

    // Tag filter
    if (tags != null && tags.isNotEmpty) {
      results = results.where((note) {
        return tags.any((tag) => note.tags.contains(tag));
      }).toList();
    }

    // Folder filter
    if (folder != null && folder.isNotEmpty) {
      results = results.where((note) => note.folderName == folder).toList();
    }

    // Date range filter
    if (startDate != null) {
      results = results.where((note) => note.createdAt >= startDate.millisecondsSinceEpoch).toList();
    }
    if (endDate != null) {
      results = results.where((note) => note.createdAt <= endDate.millisecondsSinceEpoch).toList();
    }

    // Encryption filter
    if (isEncrypted != null) {
      results = results.where((note) => note.isEncrypted == isEncrypted).toList();
    }

    // Word count filter
    if (minWordCount != null) {
      results = results.where((note) => note.wordCount >= minWordCount).toList();
    }
    if (maxWordCount != null) {
      results = results.where((note) => note.wordCount <= maxWordCount).toList();
    }

    // Has links filter
    if (hasLinks) {
      results = results.where((note) => note.extractLinks().isNotEmpty).toList();
    }

    // Has tasks filter
    if (hasTasks) {
      results = results.where((note) => note.content.contains('- [ ')).toList();
    }

    return results;
  }

  /// Fuzzy search implementation
  Future<List<Note>> fuzzySearch(String query, List<Note> notes) async {
    if (query.isEmpty) return notes;

    final lowerQuery = query.toLowerCase();
    final results = <Note>[];

    for (final note in notes) {
      double score = 0;

      // Title matches (higher weight)
      if (note.title.toLowerCase().contains(lowerQuery)) {
        score += 2.0;
      }

      // Content matches
      if (note.content.toLowerCase().contains(lowerQuery)) {
        score += 1.0;
      }

      // Tag matches
      for (final tag in note.tags) {
        if (tag.toLowerCase().contains(lowerQuery)) {
          score += 1.5;
        }
      }

      // Exact word matches
      final queryWords = lowerQuery.split(' ');
      final contentWords = note.content.toLowerCase().split(' ');
      
      for (final queryWord in queryWords) {
        if (contentWords.contains(queryWord)) {
          score += 0.5;
        }
      }

      if (score > 0) {
        results.add(note);
      }
    }

    // Sort by score (descending)
    results.sort((a, b) {
      final scoreA = _calculateSearchScore(a, lowerQuery);
      final scoreB = _calculateSearchScore(b, lowerQuery);
      return scoreB.compareTo(scoreA);
    });

    return results;
  }

  /// Search by content similarity
  Future<List<Note>> searchBySimilarity(int noteId, {int limit = 10}) async {
    final sourceNote = await _repository.getNoteById(noteId);
    if (sourceNote == null) return [];

    final allNotes = await _repository.getAllNotes();
    final similarities = <Map<String, dynamic>>[];

    for (final note in allNotes) {
      if (note.id == noteId) continue;

      final similarity = _calculateContentSimilarity(sourceNote.content, note.content);
      if (similarity > 0.1) { // Minimum similarity threshold
        similarities.add({
          'note': note,
          'similarity': similarity,
        });
      }
    }

    // Sort by similarity (descending)
    similarities.sort((a, b) => b['similarity'].compareTo(a['similarity']));

    return similarities
        .take(limit)
        .map((item) => item['note'] as Note)
        .toList();
  }

  /// Get search suggestions based on partial input
  Future<List<String>> getSearchSuggestions(String partialQuery) async {
    if (partialQuery.length < 2) return [];

    final allNotes = await _repository.getAllNotes();
    final suggestions = <String>{};

    // Extract words from titles and content
    for (final note in allNotes) {
      // Title words
      final titleWords = note.title.toLowerCase().split(' ');
      suggestions.addAll(titleWords.where((word) => 
        word.contains(partialQuery.toLowerCase()) && word.length > 2
      ));

      // Tag suggestions
      suggestions.addAll(note.tags.where((tag) => 
        tag.toLowerCase().contains(partialQuery.toLowerCase())
      ));

      // Content words (limited to avoid too many suggestions)
      final contentWords = note.content.toLowerCase().split(' ');
      suggestions.addAll(contentWords.where((word) => 
        word.contains(partialQuery.toLowerCase()) && 
        word.length > 3 && 
        word.length < 20 // Avoid very long words
      ).take(5));
    }

    return suggestions.toList()..take(10);
  }

  /// Get popular search terms
  Future<List<String>> getPopularSearchTerms({int limit = 20}) async {
    final allNotes = await _repository.getAllNotes();
    final termFrequency = <String, int>{};

    // Extract and count terms
    for (final note in allNotes) {
      // Title terms (higher weight)
      final titleWords = note.title.toLowerCase().split(' ');
      for (final word in titleWords) {
        if (word.length > 2) {
          termFrequency[word] = (termFrequency[word] ?? 0) + 2;
        }
      }

      // Tag terms
      for (final tag in note.tags) {
        termFrequency[tag.toLowerCase()] = (termFrequency[tag.toLowerCase()] ?? 0) + 3;
      }

      // Content terms
      final contentWords = note.content.toLowerCase().split(' ');
      for (final word in contentWords) {
        if (word.length > 3 && word.length < 15) {
          termFrequency[word] = (termFrequency[word] ?? 0) + 1;
        }
      }
    }

    // Sort by frequency and return top terms
    final sortedTerms = termFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sortedTerms
        .take(limit)
        .map((entry) => entry.key)
        .toList();
  }

  /// Calculate search score for a note
  double _calculateSearchScore(Note note, String query) {
    double score = 0;
    final lowerQuery = query.toLowerCase();

    // Title exact match
    if (note.title.toLowerCase() == lowerQuery) {
      score += 10.0;
    } else if (note.title.toLowerCase().contains(lowerQuery)) {
      score += 5.0;
    }

    // Content matches
    final contentLower = note.content.toLowerCase();
    if (contentLower.contains(lowerQuery)) {
      score += 2.0;
    }

    // Tag matches
    for (final tag in note.tags) {
      if (tag.toLowerCase() == lowerQuery) {
        score += 8.0;
      } else if (tag.toLowerCase().contains(lowerQuery)) {
        score += 4.0;
      }
    }

    return score;
  }

  /// Calculate content similarity using simple word overlap
  double _calculateContentSimilarity(String content1, String content2) {
    final words1 = content1.toLowerCase().split(RegExp(r'\s+')).toSet();
    final words2 = content2.toLowerCase().split(RegExp(r'\s+')).toSet();

    if (words1.isEmpty || words2.isEmpty) return 0.0;

    final intersection = words1.intersection(words2);
    final union = words1.union(words2);

    return intersection.length / union.length;
  }
}
