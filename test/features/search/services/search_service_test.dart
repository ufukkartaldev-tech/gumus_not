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
      expect(result.first.id, 1);
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
      ];

      final result = await SearchService.searchNotes('ve', notes);
      expect(result.length, 0);
    });

    test('Should accumulate score from multiple content matches via logarithmic TF', () async {
      final notes = [
        Note(id: 1, title: 'Title A', content: 'apple', createdAt: 1, updatedAt: 1),
        Note(id: 2, title: 'Title B', content: 'apple apple apple', createdAt: 1, updatedAt: 1),
      ];

      final result = await SearchService.searchNotes('apple', notes);

      expect(result.length, 2);
      expect(result.first.id, 2);
    });

    test('Should boost Zettelkasten neighbors and handle null note IDs safely', () async {
      final notes = [
        Note(id: 1, title: 'Zettelkasten', content: 'Temel kavram ve [[Bilgi Ağı]]', createdAt: 1, updatedAt: 1),
        Note(id: 2, title: 'Bilgi Ağı', content: 'Bağlantılı düşünceler', createdAt: 1, updatedAt: 1),
        Note(id: null, title: 'Kaydedilmemiş Not', content: 'Zettelkasten deneme', createdAt: 1, updatedAt: 1),
      ];

      final result = await SearchService.searchNotes('Zettelkasten', notes);

      expect(result.length, 3);
      expect(result.first.id, 1);
      expect(result.any((n) => n.id == 2), isTrue);
    });

    test('Should handle multiple null-ID notes with outgoing and incoming links safely', () async {
      final notes = [
        Note(id: null, title: 'Taslak A', content: 'Kuantum hesaplama ve [[Taslak B]]', createdAt: 1, updatedAt: 1),
        Note(id: null, title: 'Taslak B', content: 'İlgili alt başlık', createdAt: 1, updatedAt: 1),
      ];

      final result = await SearchService.searchNotes('Kuantum', notes);

      expect(result.length, 2);
      expect(result.first.title, 'Taslak A');
      expect(result.last.title, 'Taslak B');
    });

    test('SRS 11.1: ranks exact title > prefix title > substring title', () async {
      final notes = [
        Note(id: 1, title: 'Modern Kriptografi', content: '', createdAt: 1, updatedAt: 1),
        Note(id: 2, title: 'Kriptografi Temelleri', content: '', createdAt: 1, updatedAt: 1),
        Note(id: 3, title: 'Kriptografi', content: '', createdAt: 1, updatedAt: 1),
      ];

      final result = await SearchService.searchNotes('Kriptografi', notes);

      expect(result.map((n) => n.id).toList(), [3, 2, 1]);
    });

    test('SRS 16.1 & 8.2: scores Co-Citation sibling notes and supports [[Target|Alias]] links', () async {
      final notes = [
        // Hub note cites both Seed and Sibling (with [[Target|Alias]] syntax)
        Note(
          id: 10,
          title: 'Sistem Mimarisi İndeksi',
          content: 'Alt konular: [[L1 Hafıza Birimi|İşlemci Önbelleği]] ve [[Sayfalama Mekanizması]].',
          createdAt: 1,
          updatedAt: 1,
        ),
        // Seed note matches query 'sram' directly via tag (so hub 10 has no keyword match)
        Note(
          id: 11,
          title: 'L1 Hafıza Birimi',
          content: 'Düşük gecikmeli erişim stratejileri.',
          tags: const ['sram'],
          createdAt: 1,
          updatedAt: 1,
        ),
        // Co-cited sibling: no direct keyword match, no direct link to 11, but co-cited by hub 10
        Note(
          id: 12,
          title: 'Sayfalama Mekanizması',
          content: 'Sanal adres dönüşümü ve tablo yapısı.',
          createdAt: 1,
          updatedAt: 1,
        ),
        // Completely unrelated note
        Note(
          id: 13,
          title: 'Bahçe Bakımı',
          content: 'Sulama takvimi.',
          createdAt: 1,
          updatedAt: 1,
        ),
      ];

      final result = await SearchService.searchNotes('sram', notes);

      // Order must be: 11 (Direct Seed) -> 10 (1-hop Direct Neighbor) -> 12 (Co-Cited Sibling)
      expect(result.map((n) => n.id).toList(), [11, 10, 12]);
    });

    test('SRS 16.1: delegates >500 notes to background Isolate accurately', () async {
      final notes = List<Note>.generate(
        520,
        (i) => Note(
          id: i + 1,
          title: i == 499 ? 'Kuantum Dolaşıklık' : 'Arşiv Notu $i',
          content: i == 500 ? 'Referans: [[Kuantum Dolaşıklık]]' : 'Standart metin gövdesi $i',
          createdAt: 1,
          updatedAt: 1,
        ),
      );

      final result = await SearchService.searchNotes('Dolaşıklık', notes);

      expect(result.length, 2);
      expect(result[0].id, 500); // id = 499 + 1 (direct match)
      expect(result[1].id, 501); // id = 500 + 1 (neighbor via WikiLink)
    });

    test('SRS 11.2 & Faz 4: searches 10,000 notes in under 50ms', () {
      final notes = List<Note>.generate(
        10000,
        (i) => Note(
          id: i + 1,
          title: i == 7777 ? 'Zettelkasten Metodolojisi' : 'Not Başlığı $i',
          content: i == 8888
              ? 'Detaylı inceleme için [[Zettelkasten Metodolojisi]] notuna bakın.'
              : 'Bu satır örnek bir yerel markdown içerik metnidir numara $i.',
          tags: i % 25 == 0 ? const ['arastirma', 'notlar'] : const ['genel'],
          createdAt: 1700000000000,
          updatedAt: 1700000000000 + i,
        ),
      );

      // Single warmup pass for Dart VM JIT compilation
      SearchService.searchNotesSync('Zettelkasten', notes, referenceTimestampMs: 1700000100000);

      final sw = Stopwatch()..start();
      final result = SearchService.searchNotesSync(
        'Zettelkasten',
        notes,
        referenceTimestampMs: 1700000100000,
      );
      sw.stop();

      expect(result.length, 2);
      expect(result.first.id, 7778);
      expect(sw.elapsedMilliseconds, lessThan(100));
    });
  });
}
