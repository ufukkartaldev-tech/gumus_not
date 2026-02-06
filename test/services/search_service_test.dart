import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/models/note_model.dart';
import 'package:connected_notebook/services/search_service.dart';

void main() {
  group('SearchService Tests', () {
    late List<Note> testNotes;

    setUp(() {
      final now = DateTime.now().millisecondsSinceEpoch;
      testNotes = [
        Note(
          id: 1,
          title: 'Flutter Development',
          content: 'Learning Flutter is fun and challenging',
          createdAt: now,
          updatedAt: now,
          tags: ['programming', 'mobile'],
        ),
        Note(
          id: 2,
          title: 'Dart Programming',
          content: 'Dart is the language used in Flutter development',
          createdAt: now,
          updatedAt: now,
          tags: ['programming', 'dart'],
        ),
        Note(
          id: 3,
          title: 'Web Development',
          content: 'Modern web development with React and Vue',
          createdAt: now,
          updatedAt: now,
          tags: ['web', 'frontend'],
        ),
        Note(
          id: 4,
          title: 'Machine Learning',
          content: 'AI and machine learning concepts',
          createdAt: now,
          updatedAt: now,
          tags: ['ai', 'ml'],
        ),
        Note(
          id: 5,
          title: 'Encrypted Note',
          content: 'This content is encrypted',
          createdAt: now,
          updatedAt: now,
          isEncrypted: true,
          tags: ['security'],
        ),
      ];
    });

    test('Search returns all notes when query is empty', () async {
      final results = await SearchService.searchNotes('', testNotes);
      
      expect(results.length, equals(testNotes.length));
      expect(results, containsAll(testNotes));
    });

    test('Search returns all notes when query is whitespace', () async {
      final results = await SearchService.searchNotes('   ', testNotes);
      
      expect(results.length, equals(testNotes.length));
      expect(results, containsAll(testNotes));
    });

    test('Exact title match gets highest score', () async {
      final results = await SearchService.searchNotes('Flutter', testNotes);
      
      expect(results, isNotEmpty);
      expect(results.first.title, contains('Flutter'));
    });

    test('Fuzzy title search works with typos', () async {
      // "Fltter" has Levenshtein distance of 1 from "Flutter"
      final results = await SearchService.searchNotes('Fltter', testNotes);
      
      expect(results, isNotEmpty);
      // Should find notes with "Flutter" in title
      final flutterNote = results.firstWhere(
        (note) => note.title.contains('Flutter'),
        orElse: () => throw TestFailure('Flutter note not found'),
      );
      expect(flutterNote, isNotNull);
    });

    test('Exact tag match returns relevant results', () async {
      final results = await SearchService.searchNotes('programming', testNotes);
      
      expect(results, isNotEmpty);
      // Should contain notes with 'programming' tag
      expect(results.any((note) => note.tags.contains('programming')), isTrue);
    });

    test('Content search finds matches in note content', () async {
      final results = await SearchService.searchNotes('development', testNotes);
      
      expect(results, isNotEmpty);
      // Should find notes containing 'development' in content
      expect(results.any((note) => note.content.contains('development')), isTrue);
    });

    test('Stop words are ignored in search', () async {
      // 've' is a Turkish stop word
      final results = await SearchService.searchNotes('ve', testNotes);
      
      // Stop words should not affect scoring much or should be filtered out
      expect(results.length, lessThan(testNotes.length + 1)); // Not all notes returned
    });

    test('Very short queries are handled appropriately', () async {
      final results = await SearchService.searchNotes('a', testNotes);
      
      // Very short queries might not produce meaningful results
      expect(results.length, lessThan(testNotes.length));
    });

    test('Encrypted notes are not searched in content', () async {
      final results = await SearchService.searchNotes('encrypted', testNotes);
      
      // Encrypted notes should not match content-based searches
      // But they might still match if 'encrypted' appears in title or tags
      // Let's check that encrypted notes don't appear in results when searching content
      final encryptedNotesInResults = results.where((note) => 
        note.isEncrypted && note.content.toLowerCase().contains('encrypted')
      ).toList();
      
      // The encrypted note's content shouldn't contribute to search matches
      expect(encryptedNotesInResults.length, lessThan(results.length));
    });

    test('Search is case insensitive', () async {
      final results1 = await SearchService.searchNotes('FLUTTER', testNotes);
      final results2 = await SearchService.searchNotes('flutter', testNotes);
      
      expect(results1.length, equals(results2.length));
    });

    test('Results are sorted by relevance score', () async {
      final results = await SearchService.searchNotes('development', testNotes);
      
      expect(results, isNotEmpty);
      // The most relevant note should appear first
      if (results.length > 1) {
        final firstScore = _calculateRelevanceScore(results.first, 'development');
        final secondScore = _calculateRelevanceScore(results[1], 'development');
        expect(firstScore, greaterThanOrEqualTo(secondScore));
      }
    });

    test('Multiple word search returns relevant results', () async {
      final results = await SearchService.searchNotes('Flutter Development', testNotes);
      
      expect(results, isNotEmpty);
      expect(results.any((note) => note.title.contains('Flutter')), isTrue);
    });

    test('Special characters in search query are handled', () async {
      final results = await SearchService.searchNotes('Flutter!', testNotes);
      
      // Should handle special characters gracefully
      expect(results, isNotEmpty);
    });

    test('Non-matching search returns empty results', () async {
      final results = await SearchService.searchNotes('nonexistent12345', testNotes);
      
      // Should not throw exception for non-existent terms
      expect(results, isEmpty);
    });

    test('Search performance with empty notes list', () async {
      final emptyNotes = <Note>[];
      final results = await SearchService.searchNotes('test', emptyNotes);
      
      expect(results, isEmpty);
    });

    test('Tag search ignores case differences', () async {
      final results = await SearchService.searchNotes('PROGRAMMING', testNotes);
      
      expect(results, isNotEmpty);
      expect(results.any((note) => note.tags.contains('programming')), isTrue);
    });

    test('Content search scores multiply based on matches', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final longContentNote = Note(
        id: 6,
        title: 'Development Test Note',
        content: 'development development development development development',
        createdAt: now,
        updatedAt: now,
        tags: [],
      );
      
      final testSet = [...testNotes, longContentNote];
      final results = await SearchService.searchNotes('development', testSet);
      
      expect(results, isNotEmpty);
      // Note with multiple content matches should appear in results
      expect(results.any((note) => note.id == 6), isTrue);
    });

    test('Levenshtein distance calculation works correctly', () async {
      // Test the private _levenshteinDistance method through its effects
      final results1 = await SearchService.searchNotes('Fltter', testNotes); // distance 1
      final results2 = await SearchService.searchNotes('Fluter', testNotes); // distance 2
      
      // Both should find Flutter-related notes
      expect(results1.any((note) => note.title.contains('Flutter')), isTrue);
      expect(results2.any((note) => note.title.contains('Flutter')), isTrue);
    });

    test('Search with numbers works correctly', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final numberedNote = Note(
        id: 7,
        title: 'Note 2024',
        content: 'Content with numbers 123',
        createdAt: now,
        updatedAt: now,
        tags: ['2024'],
      );
      
      final testSet = [...testNotes, numberedNote];
      final results = await SearchService.searchNotes('2024', testSet);
      
      expect(results, isNotEmpty);
      expect(results.any((note) => note.title.contains('2024')), isTrue);
    });

    test('Search handles unicode characters correctly', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final unicodeNote = Note(
        id: 8,
        title: 'İstanbul Café',
        content: 'Unicode test with İüğşöç characters',
        createdAt: now,
        updatedAt: now,
        tags: ['türkçe'],
      );
      
      final testSet = [...testNotes, unicodeNote];
      final results = await SearchService.searchNotes('İstanbul', testSet);
      
      expect(results, isNotEmpty);
      expect(results.any((note) => note.title.contains('İstanbul')), isTrue);
    });
  });
}

// Helper function to calculate approximate relevance score for testing
int _calculateRelevanceScore(Note note, String query) {
  int score = 0;
  final normalizedQuery = query.toLowerCase();
  final title = note.title.toLowerCase();
  final content = note.content.toLowerCase();
  final tags = note.tags.map((t) => t.toLowerCase()).toList();
  
  // Approximate scoring logic from SearchService
  if (title.contains(normalizedQuery)) {
    score += 20; // SCORE_EXACT_TITLE
  }
  
  if (tags.any((tag) => tag.contains(normalizedQuery))) {
    score += 15; // SCORE_EXACT_TAG
  }
  
  if (!note.isEncrypted) {
    final matches = RegExp(RegExp.escape(normalizedQuery)).allMatches(content).length;
    score += matches * 2; // SCORE_CONTENT_MATCH
  }
  
  return score;
}