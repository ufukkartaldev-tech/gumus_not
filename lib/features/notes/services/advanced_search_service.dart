import 'dart:math';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/services/search_service_interface.dart';

/// Advanced search service with fuzzy matching and semantic analysis
/// Implements the SearchService interface
class AdvancedSearchService implements SearchService {
  // Weight scores
  static const int _scoreExactTitle = 50;
  static const int _scoreFuzzyTitle = 20;
  static const int _scoreExactTag = 30;
  static const int _scoreFuzzyTag = 15;
  static const int _scoreContentMatch = 5;
  static const int _scoreSemanticBoost = 25;
  static const int _scoreCoCitationBoost = 12;
  
  // Maximum Levenshtein distance for fuzzy matching
  static const int _maxDistance = 2;
  
  // Stop words (common words to ignore in fuzzy search)
  static const Set<String> _stopWords = {
    've', 'ile', 'veya', 'bir', 'bu', 'şu', 'o', 'mı', 'mi', 'da', 'de', 'ki',
    'ama', 'fakat', 'lakin', 'için', 'gibi', 'kadar', 'the', 'and', 'or', 'a',
    'an', 'in', 'on', 'at', 'to', 'for', 'of', 'with', 'by'
  };
  
  @override
  Future<List<Note>> searchNotes(String query, List<Note> allNotes) async {
    if (query.trim().isEmpty) return allNotes;
    
    final normalizedQuery = query.toLowerCase().trim();
    
    // Early exit for very short queries that are stop words
    if (_stopWords.contains(normalizedQuery) && normalizedQuery.length < 3) {
      return _performSimpleSearch(normalizedQuery, allNotes);
    }
    
    return _performAdvancedSearch(normalizedQuery, allNotes);
  }
  
  @override
  Future<List<Note>> getLinkedNotes(int noteId, List<Note> allNotes) async {
    final note = allNotes.firstWhere((n) => n.id == noteId, orElse: () => null);
    if (note == null) return [];
    
    final linkedNoteIds = note.extractLinks();
    final linkedNotes = <Note>[];
    
    for (final linkText in linkedNoteIds) {
      final targetNote = allNotes.firstWhere(
        (n) => n.title.toLowerCase() == linkText.toLowerCase(),
        orElse: () => null,
      );
      
      if (targetNote != null) {
        linkedNotes.add(targetNote);
      }
    }
    
    return linkedNotes;
  }
  
  @override
  Future<List<Note>> getReferringNotes(int noteId, List<Note> allNotes) async {
    final note = allNotes.firstWhere((n) => n.id == noteId, orElse: () => null);
    if (note == null) return [];
    
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
  
  // Private helper methods
  
  List<Note> _performSimpleSearch(String query, List<Note> allNotes) {
    return allNotes.where((note) {
      return note.title.toLowerCase().contains(query) ||
             note.tags.any((tag) => tag.toLowerCase().contains(query)) ||
             (!note.isEncrypted && note.content.toLowerCase().contains(query));
    }).toList();
  }
  
  List<Note> _performAdvancedSearch(String query, List<Note> allNotes) {
    final scoredNotes = <Map<String, dynamic>>[];
    
    // Phase 1: Keyword scoring
    for (final note in allNotes) {
      int score = _calculateKeywordScore(note, query);
      
      if (score > 0) {
        scoredNotes.add({
          'note': note,
          'score': score,
        });
      }
    }
    
    // Phase 2: Semantic analysis (if we have scored notes)
    if (scoredNotes.isNotEmpty) {
      final semanticScores = _calculateSemanticScores(scoredNotes, allNotes);
      
      // Combine scores
      final finalScores = <int, int>{};
      for (final item in scoredNotes) {
        final note = item['note'] as Note;
        final keywordScore = item['score'] as int;
        final semanticScore = semanticScores[note.id] ?? 0;
        finalScores[note.id!] = keywordScore + semanticScore;
      }
      
      // Add notes that only have semantic scores
      for (final entry in semanticScores.entries) {
        if (!finalScores.containsKey(entry.key)) {
          finalScores[entry.key] = entry.value;
        }
      }
      
      // Sort by score
      final sortedNotes = finalScores.entries
          .where((entry) => entry.value > 0)
          .map((entry) {
            final note = allNotes.firstWhere((n) => n.id == entry.key);
            return {'note': note, 'score': entry.value};
          })
          .toList()
        ..sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
      
      return sortedNotes.map((item) => item['note'] as Note).toList();
    }
    
    return [];
  }
  
  int _calculateKeywordScore(Note note, String query) {
    int score = 0;
    final title = note.title.toLowerCase();
    final content = note.content.toLowerCase();
    final tags = note.tags.map((t) => t.toLowerCase()).toList();
    
    // 1. Title matches
    if (title.contains(query)) {
      score += _scoreExactTitle;
    } else if (!_stopWords.contains(query) && query.length > 2) {
      final words = title.split(' ');
      for (final word in words) {
        if (_levenshteinDistance(word, query) <= _maxDistance) {
          score += _scoreFuzzyTitle;
          break;
        }
      }
    }
    
    // 2. Tag matches
    for (final tag in tags) {
      if (tag.contains(query)) {
        score += _scoreExactTag;
      } else if (!_stopWords.contains(query) && query.length > 2 && 
                 _levenshteinDistance(tag, query) <= _maxDistance) {
        score += _scoreFuzzyTag;
      }
    }
    
    // 3. Content matches (only for non-encrypted notes)
    if (!note.isEncrypted && !_stopWords.contains(query)) {
      final pattern = RegExp(RegExp.escape(query));
      final matches = pattern.allMatches(content).length;
      score += matches * _scoreContentMatch;
    }
    
    return score;
  }
  
  Map<int, int> _calculateSemanticScores(
    List<Map<String, dynamic>> scoredNotes, 
    List<Note> allNotes
  ) {
    final semanticScores = <int, int>{};
    
    // Map note titles to IDs for quick lookup
    final titleToId = {
      for (final note in allNotes) 
        note.title.toLowerCase(): note.id ?? -1
    };
    
    // Map note IDs to outgoing links
    final noteOutgoingLinks = <int, List<String>>{};
    final linkRegex = RegExp(r'\[\[(.*?)\]\]');
    
    for (final note in allNotes) {
      final matches = linkRegex.allMatches(note.content);
      noteOutgoingLinks[note.id!] = 
          matches.map((m) => m.group(1)!.toLowerCase()).toList();
    }
    
    // A) Direct neighbor support
    for (final item in scoredNotes) {
      final seedNote = item['note'] as Note;
      final seedScore = item['score'] as int;
      
      // Boost notes that this note links to
      final targets = noteOutgoingLinks[seedNote.id!] ?? [];
      for (final targetTitle in targets) {
        final targetId = titleToId[targetTitle];
        if (targetId != null && targetId != seedNote.id && targetId != -1) {
          semanticScores[targetId] = 
              (semanticScores[targetId] ?? 0) + _scoreSemanticBoost;
        }
      }
      
      // Boost notes that link to this note
      for (final otherNote in allNotes) {
        if (noteOutgoingLinks[otherNote.id!]?.contains(seedNote.title.toLowerCase()) ?? false) {
          semanticScores[otherNote.id!] = 
              (semanticScores[otherNote.id!] ?? 0) + _scoreSemanticBoost;
        }
      }
    }
    
    // B) Co-citation support (notes that link to the same target)
    // This is computationally expensive, so we only do it for high-scoring seeds
    final highScoreNotes = scoredNotes
        .where((item) => (item['score'] as int) > _scoreExactTitle)
        .map((item) => item['note'] as Note)
        .toList();
    
    for (final seedNote in highScoreNotes) {
      final seedTargets = noteOutgoingLinks[seedNote.id!] ?? [];
      
      for (final otherNote in allNotes) {
        if (otherNote.id == seedNote.id) continue;
        
        final otherTargets = noteOutgoingLinks[otherNote.id!] ?? [];
        final commonTargets = seedTargets.toSet().intersection(otherTargets.toSet());
        
        if (commonTargets.isNotEmpty) {
          semanticScores[otherNote.id!] = 
              (semanticScores[otherNote.id!] ?? 0) + 
              (commonTargets.length * _scoreCoCitationBoost);
        }
      }
    }
    
    return semanticScores;
  }
  
  /// Levenshtein distance calculation for fuzzy matching
  int _levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;
    
    List<int> v0 = List<int>.filled(s2.length + 1, 0);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);
    
    for (int i = 0; i < s2.length + 1; i++) {
      v0[i] = i;
    }
    
    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      
      for (int j = 0; j < s2.length; j++) {
        int cost = (s1.codeUnitAt(i) == s2.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      
      for (int j = 0; j < s2.length + 1; j++) {
        v0[j] = v1[j];
      }
    }
    
    return v1[s2.length];
  }
}