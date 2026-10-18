import 'dart:math';
import 'package:connected_notebook/features/notes/models/note_model.dart';

class SearchService {
  // Ağırlık Puanları
  static const int SCORE_EXACT_TITLE = 50; // Artırıldı
  static const int SCORE_FUZZY_TITLE = 20;
  static const int SCORE_EXACT_TAG = 30;
  static const int SCORE_FUZZY_TAG = 15;
  static const int SCORE_CONTENT_MATCH = 5;
  
  // ZETTELKASTEN (Semantic) Sabitleri
  static const int SCORE_SEMANTIC_BOOST = 25; // Doğrudan bağlı notlara (Neighbor)
  static const int SCORE_CO_CITATION_BOOST = 12; // Aynı nota bağlanan kardeş notlara

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

    for (int index = 0; index < candidateNotes.length; index++) {
      final note = candidateNotes[index];
      final int nodeKey = note.id ?? -(index + 1);

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
            if ((word.length - normalizedQuery.length).abs() <= MAX_DISTANCE &&
                _levenshteinDistance(word, normalizedQuery) <= MAX_DISTANCE) {
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
        } else if (!STOP_WORDS.contains(normalizedQuery) &&
            normalizedQuery.length > 2 &&
            (tag.length - normalizedQuery.length).abs() <= MAX_DISTANCE &&
            _levenshteinDistance(tag, normalizedQuery) <= MAX_DISTANCE) {
          score += SCORE_FUZZY_TAG;
        }
      }

      // 3. İÇERİK KONTROLÜ
      if (!note.isEncrypted && !STOP_WORDS.contains(normalizedQuery)) {
        final contentMatches = RegExp(RegExp.escape(normalizedQuery)).allMatches(content).length;
        score += contentMatches * SCORE_CONTENT_MATCH;
      }

      if (score > 0) {
        scoredNotes.add({
          'key': nodeKey,
          'note': note,
          'score': score,
        });
      }
    }

    // 4. ZETTELKASTEN SEMANTİK ANALİZ (Graf Üzerinden Puanlama)
    // Bu aşamada, ilk aşamadan puan almış "Çekirdek (Seed)" notların komşularına puan dağıtıyoruz.
    final Map<int, int> semanticScores = {};
    
    // Her notun bağlantılarını hızlıca haritalayalım (Regex ile)
    final linkRegex = RegExp(r'\[\[(.*?)\]\]');
    final Map<int, List<String>> noteOutgoingLinks = {};
    final Map<String, int> titleToId = {};
    final Map<int, Note> resultNodes = {};

    for (int index = 0; index < allNotes.length; index++) {
      final note = allNotes[index];
      final int nodeKey = note.id ?? -(index + 1);
      resultNodes[nodeKey] = note;
      titleToId[note.title.toLowerCase()] = nodeKey;

      if (note.isEncrypted) {
        noteOutgoingLinks[nodeKey] = const [];
        continue;
      }
      final matches = linkRegex.allMatches(note.content);
      noteOutgoingLinks[nodeKey] = matches
          .map((m) => m.group(1)?.toLowerCase())
          .whereType<String>()
          .toList();
    }

    // A) Komşu Desteği (Direct Neighbors)
    // Eğer bir not "Bilgisayar Mimarisi" ise, ona link veren veya ondan link alan tüm notlara puan ver.
    for (var item in scoredNotes) {
      final seedNote = item['note'] as Note;
      final seedId = item['key'] as int;

      // Bu notun bağlandığı (target) notlara puan ekle
      final targets = noteOutgoingLinks[seedId] ?? const [];
      for (var targetTitle in targets) {
        final targetId = titleToId[targetTitle];
        if (targetId != null && targetId != seedId) {
          semanticScores[targetId] =
              (semanticScores[targetId] ?? 0) + SCORE_SEMANTIC_BOOST;
        }
      }

      // Bu nota bağlanan (source) notları bul ve onlara puan ekle
      final seedTitleLower = seedNote.title.toLowerCase();
      noteOutgoingLinks.forEach((otherId, outgoing) {
        if (otherId != seedId && outgoing.contains(seedTitleLower)) {
          semanticScores[otherId] =
              (semanticScores[otherId] ?? 0) + SCORE_SEMANTIC_BOOST;
        }
      });
    }

    // B) Co-Citation Desteği (Kardeş Notlar)
    // İki not aynı konuya (target) referans veriyorsa aralarında anlamsal bir bağ vardır.
    // Örn: Hem "x86" hem "ARM" notu "Mimari"ye link veriyorsa, birini aratınca diğeri de yükselmeli.
    // (Karmaşıklık nedeniyle sadece yüksek puanlı çekirdekler üzerinden hesaplanacaktır)

    // 5. TÜM PUANLARI BİRLEŞTİR
    final Map<int, int> directScores = {};
    final Map<int, int> finalScores = {};

    // Önce keyword puanlarını ekle
    for (var item in scoredNotes) {
      final id = item['key'] as int;
      final directScore = item['score'] as int;
      directScores[id] = directScore;
      finalScores[id] = directScore;
    }

    // Sonra semantik puanları ekle (Tüm notlar üzerinden, çünkü hiç keyword eşleşmesi olmayıp sadece bağlı olanlar da gelebilir)
    semanticScores.forEach((id, sScore) {
      if (resultNodes.containsKey(id)) {
        finalScores[id] = (finalScores[id] ?? 0) + sScore;
      }
    });

    final List<Map<String, dynamic>> finalResultList = [];
    finalScores.forEach((id, totalScore) {
      final node = resultNodes[id];
      if (totalScore > 0 && node != null) {
        finalResultList.add({
          'note': node,
          'score': totalScore,
          'hasDirectMatch': (directScores[id] ?? 0) > 0,
        });
      }
    });

    // Sonuçları sırala: Doğrudan arama terimiyle eşleşen (seed) notlar,
    // yalnızca komşuluk (semantic boost) ile gelen notların önünde yer alır.
    finalResultList.sort((a, b) {
      final aDirect = a['hasDirectMatch'] as bool;
      final bDirect = b['hasDirectMatch'] as bool;
      if (aDirect != bDirect) {
        return aDirect ? -1 : 1;
      }
      return (b['score'] as int).compareTo(a['score'] as int);
    });

    return finalResultList.map((item) => item['note'] as Note).toList();
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
