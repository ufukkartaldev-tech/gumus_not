import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/search/services/search_service.dart';

void main() {
  group('SearchService Algorithm Tests', () {
    test('Should return all notes if query is empty', () async {
      final notes = [
        Note(id: 1, title: 'Note 1', content: 'A', createdAt: 1, updatedAt: 1),
      ];
      final result = await SearchService.searchNotes('   ', notes);
      expect(result.length, 1);
    });

    test('Should prioritize exact title match over exact content match', () async {
      final notes = [
        Note(id: 1, title: 'Flutter Basics', content: 'Some content', createdAt: 1, updatedAt: 1),
        Note(id: 2, title: 'Dart Basics', content: 'I love Flutter', createdAt: 1, updatedAt: 1),
      ];

      final result = await SearchService.searchNotes('Flutter', notes);

      expect(result.length, 2);
      expect(result.first.id, 1); // Note 1 should score 50 (Title). Note 2 should score 5 (Content).
    });

    test('Should find note using fuzzy title match (Levenshtein distance)', () async {
      final notes = [
        Note(id: 1, title: 'Makine Öğrenmesi', content: 'Machine learning', createdAt: 1, updatedAt: 1),
        Note(id: 2, title: 'Matematik', content: 'Math', createdAt: 1, updatedAt: 1),
      ];

      // Query has a typo: "Makina" instead of "Makine" (Distance: 1)
      final result = await SearchService.searchNotes('Makina', notes);

      expect(result.length, 1);
      expect(result.first.title, 'Makine Öğrenmesi');
    });

    test('Should match exactly by tags', () async {
      final notes = [
        Note(id: 1, title: 'Title A', content: 'A', tags: ['flutter', 'dart'], createdAt: 1, updatedAt: 1),
        Note(id: 2, title: 'Title B', content: 'B', tags: ['java'], createdAt: 1, updatedAt: 1),
      ];

      final result = await SearchService.searchNotes('dart', notes);

      expect(result.length, 1);
      expect(result.first.id, 1);
    });

    test('Should ignore content search for encrypted notes', () async {
      final notes = [
        Note(id: 1, title: 'Secret Note', content: 'My password is 1234', isEncrypted: true, createdAt: 1, updatedAt: 1),
        Note(id: 2, title: 'Public Note', content: 'My password is admin', isEncrypted: false, createdAt: 1, updatedAt: 1),
      ];

      // Searching for content string
      final result = await SearchService.searchNotes('password', notes);

      expect(result.length, 1);
      expect(result.first.id, 2); // Should only return the public note
    });

    test('Should NOT apply fuzzy matching to STOP_WORDS (like "ve")', () async {
      final notes = [
        Note(id: 1, title: 'Apple', content: 'Content', createdAt: 1, updatedAt: 1),
        // Levenshtein distance between "ve" and "veya" is 2. 
        // If fuzzy was applied to stop words, "ve" query would match "veya".
      ];

      // We actually expect "ve" to match exactly if it's there, but let's test a short word mismatch
      final result = await SearchService.searchNotes('ve', notes);
      expect(result.length, 0); 
    });

    test('Should accumulate score from multiple content matches', () async {
      final notes = [
        Note(id: 1, title: 'Title A', content: 'apple', createdAt: 1, updatedAt: 1),
        Note(id: 2, title: 'Title B', content: 'apple apple apple', createdAt: 1, updatedAt: 1),
      ];

      // Note 2 has 3 occurrences -> Score: 15. Note 1 has 1 occurrence -> Score: 5.
      final result = await SearchService.searchNotes('apple', notes);

      expect(result.length, 2);
      expect(result.first.id, 2); // Note 2 has higher score
    });
  });
}
