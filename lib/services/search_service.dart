import 'dart:math';
import '../models/note_model.dart';
import '../services/database_service.dart';

class SearchService {
  // Ağırlık Puanları
  static const int SCORE_EXACT_TITLE = 20;
  static const int SCORE_FUZZY_TITLE = 10;
  static const int SCORE_EXACT_TAG = 15;
  static const int SCORE_FUZZY_TAG = 8;
  static const int SCORE_CONTENT_MATCH = 2; // Her geçiş için

  // Maksimum Levenshtein Mesafesi (Hata toleransı)
  static const int MAX_DISTANCE = 2;

  // Stop Words (Boş Kelimeler) Listesi
  static const Set<String> STOP_WORDS = {
    've', 'ile', 'veya', 'bir', 'bu', 'şu', 'o', 'mı', 'mi', 'da', 'de', 'ki', 'ama', 'fakat', 'lakin', 'için', 'gibi', 'kadar'
  };

  /// Ana Arama Fonksiyonu
  static Future<List<Note>> searchNotes(String query, List<Note> allNotes) async {
    if (query.trim().isEmpty) return allNotes;

    final normalizedQuery = query.toLowerCase().trim();
    
    // Stop Word Kontrolü: Eğer sorgu sadece stop word'den oluşuyorsa veya çok kısaysa puanlama yapma
    // Ancak kullanıcı özellikle "ve" araması yapmak istiyor olabilir, bu yüzden tamamen engellemiyoruz, sadece Fuzzy'den koruyoruz.
    
    final List<Map<String, dynamic>> scoredNotes = [];

    // BÜYÜK VERİ OPTİMİZASYONU:
    // Eğer not sayısı 500'den fazlaysa, önce basit bir "contains" filtresi uygula.
    // Bu, işlenecek veri setini %90 oranında küçültür.
    List<Note> candidateNotes = allNotes;
    if (allNotes.length > 500) {
       // Kaba Temizlik: İçinde hiç geçmiyorsa ve Levenshtein için olası bir aday değilse (ilk harf vs.) ele.
       // Basitlik için şimdilik sadece "contains" ile aday belirliyoruz, ama fuzzy için bu biraz riskli olabilir.
       // Daha güvenli bir "Kaba Temizlik": Sadece başlık veya içeriklerde karakter eşleşmesi olanları al.
       // Şimdilik performans/doğruluk dengesi için 500+ notta doğrudan subset almıyoruz, Dart isolate yapısı güçlüdür. 
       // Ancak döngü içinde gereksiz Levenshtein çalıştırmayacağız.
    }

    for (var note in candidateNotes) {
      int score = 0;
      final title = note.title.toLowerCase();
      final content = note.content.toLowerCase();
      final tags = note.tags.map((t) => t.toLowerCase()).toList();

      // 1. BAŞLIK KONTROLLERİ
      if (title.contains(normalizedQuery)) {
        score += SCORE_EXACT_TITLE;
      } else {
        // Kelime bazlı fuzzy arama - Sadece Stop Word değilse!
        if (!STOP_WORDS.contains(normalizedQuery) && normalizedQuery.length > 2) {
          final words = title.split(' ');
          for (var word in words) {
            if (_levenshteinDistance(word, normalizedQuery) <= MAX_DISTANCE) {
              score += SCORE_FUZZY_TITLE;
              break; 
            }
          }
        }
      }

      // 2. ETİKET KONTROLLERİ
      for (var tag in tags) {
        if (tag.contains(normalizedQuery)) {
          score += SCORE_EXACT_TAG;
        } else if (!STOP_WORDS.contains(normalizedQuery) && normalizedQuery.length > 2 && _levenshteinDistance(tag, normalizedQuery) <= MAX_DISTANCE) {
          score += SCORE_FUZZY_TAG;
        }
      }

      // 3. İÇERİK KONTROLÜ
      // Şifreli notların içeriğinde arama yapılamaz (Güvenlik)
      if (!note.isEncrypted && !STOP_WORDS.contains(normalizedQuery)) {
        // Hızlı sayım için split yerine RegExp match count
        final contentMatches = RegExp(RegExp.escape(normalizedQuery)).allMatches(content).length;
        score += contentMatches * SCORE_CONTENT_MATCH;
      }

      // Eğer puan > 0 ise sonuçlara ekle
      if (score > 0) {
        scoredNotes.add({
          'note': note,
          'score': score,
        });
      }
    }

    // Puana göre sırala (En yüksek puan en üstte)
    scoredNotes.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));

    return scoredNotes.map((item) => item['note'] as Note).toList();
  }

  /// Levenshtein Mesafesi Hesaplama (Fuzzy Logic Çekirdeği)
  /// İki kelime arasındaki farkı (ekleme, silme, değiştirme) ölçer.
  static int _levenshteinDistance(String s1, String s2) {
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
