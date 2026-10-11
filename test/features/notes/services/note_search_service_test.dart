import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/repositories/mock_note_repository.dart';
import 'package:connected_notebook/features/notes/services/note_search_service.dart';

void main() {
  late MockNoteRepository mockRepo;
  late NoteSearchService searchService;

  setUp(() {
    mockRepo = MockNoteRepository();
    searchService = NoteSearchService(mockRepo);
  });

  group('Turkish Character & Normalization Tests', () {
    test('Should normalize Turkish characters seamlessly', () {
      expect(NoteSearchService.normalize('Şekerli Kahve'), 'sekerli kahve');
      expect(NoteSearchService.normalize('İSTANBUL ÇIKIŞI'), 'istanbul cikisi');
      expect(NoteSearchService.normalize('Öğrenci Günlüğü'), 'ogrenci gunlugu');
    });

    test('Should match Turkish characters regardless of input variant', () async {
      final notes = [
        Note(id: 1, title: 'Öğrenci Rehberi', content: 'Üniversite notları', createdAt: 1, updatedAt: 1),
        Note(id: 2, title: 'İş Planı', content: 'Şirket projeleri', createdAt: 1, updatedAt: 1),
      ];

      // Query with ASCII chars matching Turkish chars
      final result1 = await searchService.fuzzySearch('ogrenci', notes);
      expect(result1.length, 1);
      expect(result1.first.id, 1);

      // Query with Turkish chars matching ASCII/Turkish
      final result2 = await searchService.fuzzySearch('is plani', notes);
      expect(result2.length, 1);
      expect(result2.first.id, 2);
    });
  });

  group('Weighted Relevance Scoring Tests', () {
    test('Should prioritize exact title match over content match', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final notes = [
        Note(
          id: 1,
          title: 'Algoritmalar ve Veri Yapıları',
          content: 'Detaylı açıklamalar',
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          id: 2,
          title: 'Genel Notlar',
          content: 'Burada Algoritmalar konusu işlenecek',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final results = await searchService.fuzzySearch('Algoritmalar', notes);
      expect(results.length, 2);
      expect(results.first.id, 1); // Note 1 should rank first due to title weight
    });

    test('Should rank tag match above body content match', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final notes = [
        Note(
          id: 1,
          title: 'Yazılım Notu',
          content: 'Bu not flutter içerir',
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          id: 2,
          title: 'Faydalı Araçlar',
          content: 'Mobil geliştirme kütüphaneleri',
          tags: ['flutter'],
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final results = await searchService.fuzzySearch('flutter', notes);
      expect(results.length, 2);
      expect(results.first.id, 2); // Tag match (Note 2) should outrank plain content match (Note 1)
    });

    test('Should prioritize recent notes when match scores are close', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final oldTime = now - (60 * 24 * 60 * 60 * 1000); // 60 days ago

      final notes = [
        Note(
          id: 1,
          title: 'Toplantı Notu',
          content: 'Proje hedefleri',
          createdAt: oldTime,
          updatedAt: oldTime,
        ),
        Note(
          id: 2,
          title: 'Toplantı Notu',
          content: 'Proje hedefleri',
          createdAt: now,
          updatedAt: now, // Updated today
        ),
      ];

      final results = await searchService.fuzzySearch('Toplantı', notes);
      expect(results.length, 2);
      expect(results.first.id, 2); // More recent note should be first
    });
  });

  group('Fuzzy Search & Typo Tolerance Tests', () {
    test('Should find notes with single-letter typo (Levenshtein distance 1)', () async {
      final notes = [
        Note(id: 1, title: 'Mimarlık İlkeleri', content: 'Yazılım tasarımı', createdAt: 1, updatedAt: 1),
        Note(id: 2, title: 'Tarihçe', content: 'Eski zamanlar', createdAt: 1, updatedAt: 1),
      ];

      // "Mimarlik" instead of "Mimarlık" with typo: "Mimarlk"
      final results = await searchService.fuzzySearch('Mimarlk', notes);
      expect(results.length, 1);
      expect(results.first.id, 1);
    });

    test('Should ignore content matching for encrypted notes', () async {
      final notes = [
        Note(id: 1, title: 'Açık Not', content: 'Gizli kelime gizli_anahtar', isEncrypted: false, createdAt: 1, updatedAt: 1),
        Note(id: 2, title: 'Kilitli Kasa', content: 'Gizli kelime gizli_anahtar', isEncrypted: true, createdAt: 1, updatedAt: 1),
      ];

      final results = await searchService.fuzzySearch('gizli_anahtar', notes);
      expect(results.length, 1);
      expect(results.first.id, 1); // Encrypted note content must not match
    });
  });

  group('Code Block & Advanced Filtering Tests', () {
    test('Should match and boost queries inside code blocks', () async {
      final now = DateTime.now().millisecondsSinceEpoch;
      final notes = [
        Note(
          id: 1,
          title: 'Kod Snippet',
          content: 'Aşağıda fonksiyon var:\n```dart\nvoid fetchUserData() {}\n```',
          createdAt: now,
          updatedAt: now,
        ),
        Note(
          id: 2,
          title: 'Düz Yazı',
          content: 'Kullanıcı verisi için fetchUserData çağrısı yapılabilir.',
          createdAt: now,
          updatedAt: now,
        ),
      ];

      final results = await searchService.fuzzySearch('fetchUserData', notes);
      expect(results.length, 2);
      expect(results.first.id, 1); // Code block match receives extra boost
    });

    test('Advanced search should filter by tasks and folders', () async {
      mockRepo.addMockNotes([
        Note(id: 1, title: 'Yapılacaklar', content: '- [ ] Görev 1', folderName: 'İş', createdAt: 100, updatedAt: 100),
        Note(id: 2, title: 'Bitenler', content: '- [x] Görev 2', folderName: 'İş', createdAt: 200, updatedAt: 200),
        Note(id: 3, title: 'Fikirler', content: 'Düz metin', folderName: 'Kişisel', createdAt: 300, updatedAt: 300),
      ]);

      final taskResults = await searchService.advancedSearch(
        hasTasks: true,
        folder: 'İş',
      );

      expect(taskResults.length, 2);
      expect(taskResults.any((n) => n.id == 3), isFalse);
    });
  });
}
