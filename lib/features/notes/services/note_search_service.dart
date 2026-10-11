import 'dart:math';
import '../models/note_model.dart';
import '../repositories/note_repository.dart';
import 'backlink_service.dart';

/// Gelişmiş, Türkçe karakter duyarsız ve hata toleranslı (fuzzy) not arama servisi.
/// Tek Sorumluluk Prensibi (SRP): Yalnızca arama, filtreleme ve alaka düzeyi skorlamasını yönetir.
class NoteSearchService {
  final NoteRepository _repository;
  final BacklinkService? _backlinkService;

  NoteSearchService(this._repository, [this._backlinkService]);

  /// Stop words (Gereksiz bağlaçlar/boş kelimeler)
  static const Set<String> _stopWords = {
    've', 'ile', 'veya', 'bir', 'bu', 'su', 'o', 'mi', 'da', 'de', 'ki', 'ama', 'fakat', 'icin', 'gibi', 'kadar'
  };

  /// Türkçe karakter ve büyük/küçük harf normalizasyonu
  /// 'ı' -> 'i', 'ğ' -> 'g', 'ü' -> 'u', 'ş' -> 's', 'ö' -> 'o', 'ç' -> 'c'
  static String normalize(String text) {
    if (text.isEmpty) return '';
    return text
        .toLowerCase()
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'i')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'g')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'u')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 's')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'o')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'c')
        .trim();
  }

  /// Levenshtein Edit Distance (Yazım hatası mesafesi)
  static int levenshteinDistance(String s1, String s2) {
    if (s1 == s2) return 0;
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<int> v0 = List<int>.generate(s2.length + 1, (i) => i);
    List<int> v1 = List<int>.filled(s2.length + 1, 0);

    for (int i = 0; i < s1.length; i++) {
      v1[0] = i + 1;
      for (int j = 0; j < s2.length; j++) {
        final cost = (s1.codeUnitAt(i) == s2.codeUnitAt(j)) ? 0 : 1;
        v1[j + 1] = min(v1[j] + 1, min(v0[j + 1] + 1, v0[j] + cost));
      }
      for (int j = 0; j <= s2.length; j++) {
        v0[j] = v1[j];
      }
    }
    return v1[s2.length];
  }

  /// Kelimeler arası toleranslı eşleşme kontrolü
  static bool isFuzzyMatch(String word, String query) {
    if (query.length < 3) return word == query;
    if ((word.length - query.length).abs() > 2) return false;
    final maxDist = query.length <= 4 ? 1 : 2;
    return levenshteinDistance(word, query) <= maxDist;
  }

  /// Doğrudan arama metodu (Geriye dönük uyumluluk ve UI kısayolu için)
  Future<List<Note>> search(String query, [List<Note>? notes]) async {
    final noteList = notes ?? await _repository.getAllNotes();
    return fuzzySearch(query, noteList);
  }

  /// Ağırlıklı alaka düzeyi (Relevance Scoring) ve Fuzzy tabanlı arama
  Future<List<Note>> fuzzySearch(String query, List<Note> notes) async {
    final rawQuery = query.trim();
    if (rawQuery.isEmpty) return List<Note>.from(notes);

    final normalizedQuery = normalize(rawQuery);
    final queryWords = normalizedQuery
        .split(RegExp(r'\s+'))
        .where((w) => w.isNotEmpty && !_stopWords.contains(w))
        .toList();

    final now = DateTime.now().millisecondsSinceEpoch;
    final oneDayMs = 24 * 60 * 60 * 1000;
    final oneWeekMs = 7 * oneDayMs;
    final oneMonthMs = 30 * oneDayMs;

    final scoredList = <MapEntry<Note, double>>[];

    for (final note in notes) {
      double score = 0.0;
      final normTitle = normalize(note.title);
      final normTags = note.tags.map(normalize).toList();
      final normContent = note.isEncrypted ? '' : normalize(note.content);

      // --- 1. BAŞLIK EŞLEŞMELERİ (En Yüksek Ağırlık) ---
      if (normTitle == normalizedQuery) {
        score += 100.0; // Tam başlık eşleşmesi (10x)
      } else if (normTitle.startsWith(normalizedQuery)) {
        score += 60.0; // Başlık başlangıcı eşleşmesi
      } else if (normTitle.contains(normalizedQuery)) {
        score += 35.0; // Başlık alt metin eşleşmesi
      }

      final titleWords = normTitle.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
      for (final qWord in queryWords) {
        for (final tWord in titleWords) {
          if (tWord == qWord) {
            score += 25.0;
          } else if (isFuzzyMatch(tWord, qWord)) {
            score += 15.0; // Başlıkta yazım hatası toleransı
          }
        }
      }

      // --- 2. ETİKET EŞLEŞMELERİ (Yüksek Ağırlık) ---
      for (final tag in normTags) {
        final cleanTag = tag.replaceAll('#', '');
        final cleanQuery = normalizedQuery.replaceAll('#', '');
        if (cleanTag == cleanQuery) {
          score += 50.0; // Tam etiket eşleşmesi (5x)
        } else if (cleanTag.contains(cleanQuery)) {
          score += 30.0;
        } else if (isFuzzyMatch(cleanTag, cleanQuery)) {
          score += 15.0; // Etikette fuzzy tolerans
        }
      }

      // --- 3. İÇERİK VE KOD BLOKLARI EŞLEŞMELERİ (Standart Ağırlık) ---
      if (!note.isEncrypted && normContent.isNotEmpty) {
        // Kod bloklarında arama: ```...```
        final codeBlocks = RegExp(r'```[\s\S]*?```').allMatches(note.content);
        for (final match in codeBlocks) {
          final blockText = normalize(match.group(0) ?? '');
          if (blockText.contains(normalizedQuery)) {
            score += 20.0; // Kod bloğu içinde tam eşleşme
          }
        }

        // İçerik genelinde tam sorgu eşleşmesi
        if (normContent.contains(normalizedQuery)) {
          score += 15.0;
        }

        // Kelime bazlı içerik eşleşmesi
        final contentWords = normContent.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
        int contentWordMatches = 0;
        for (final qWord in queryWords) {
          for (final cWord in contentWords) {
            if (cWord == qWord) {
              contentWordMatches++;
              if (contentWordMatches >= 5) break; // Çok fazla puan yığılmasını önle
            } else if (isFuzzyMatch(cWord, qWord)) {
              score += 4.0;
            }
          }
        }
        score += (contentWordMatches * 3.0);
      }

      // --- 4. GÜNCELLİK PUANI (Recency Boost) ---
      final ageMs = now - note.updatedAt;
      if (ageMs <= oneDayMs) {
        score += 5.0; // Son 24 saatte güncellenen not
      } else if (ageMs <= oneWeekMs) {
        score += 3.0; // Son 1 haftada güncellenen not
      } else if (ageMs <= oneMonthMs) {
        score += 1.0; // Son 1 ayda güncellenen not
      }

      // --- 5. BAĞLANTI (Backlink) DESTEĞİ ---
      if (_backlinkService != null) {
        final links = note.extractLinks();
        if (links.isNotEmpty) {
          score += 2.0; // İlişkisel zenginlik katkısı
        }
      }

      // Yalnızca eşleşen (puanı > 5 olan) notları listeye ekle
      // (Salt güncellik puanı tek başına eşleşme yaratamaz)
      final pureMatchScore = score - (ageMs <= oneDayMs ? 5.0 : ageMs <= oneWeekMs ? 3.0 : ageMs <= oneMonthMs ? 1.0 : 0.0);
      if (pureMatchScore > 0) {
        scoredList.add(MapEntry(note, score));
      }
    }

    // Skora göre azalan sırada sırala (En alakalı en üstte)
    scoredList.sort((a, b) => b.value.compareTo(a.value));

    return scoredList.map((entry) => entry.key).toList();
  }

  /// Çok kriterli gelişmiş arama
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

    // 1. Akıllı metin araması (Puanlamaya göre sıralı)
    if (query.trim().isNotEmpty) {
      results = await fuzzySearch(query, results);
    }

    // 2. Etiket filtreleme
    if (tags != null && tags.isNotEmpty) {
      final normalizedFilterTags = tags.map(normalize).toSet();
      results = results.where((note) {
        return note.tags.any((tag) => normalizedFilterTags.contains(normalize(tag)));
      }).toList();
    }

    // 3. Klasör filtreleme
    if (folder != null && folder.isNotEmpty && folder != 'Tümü') {
      results = results.where((note) => note.folderName == folder).toList();
    }

    // 4. Tarih filtreleme
    if (startDate != null) {
      results = results.where((note) => note.createdAt >= startDate.millisecondsSinceEpoch).toList();
    }
    if (endDate != null) {
      results = results.where((note) => note.createdAt <= endDate.millisecondsSinceEpoch).toList();
    }

    // 5. Şifrelilik filtresi
    if (isEncrypted != null) {
      results = results.where((note) => note.isEncrypted == isEncrypted).toList();
    }

    // 6. Kelime sayısı filtresi
    if (minWordCount != null) {
      results = results.where((note) => note.wordCount >= minWordCount).toList();
    }
    if (maxWordCount != null) {
      results = results.where((note) => note.wordCount <= maxWordCount).toList();
    }

    // 7. Bağlantı (Link) filtresi
    if (hasLinks) {
      results = results.where((note) => note.extractLinks().isNotEmpty).toList();
    }

    // 8. Görev (Task) filtresi
    if (hasTasks) {
      results = results.where((note) => note.content.contains('- [ ]') || note.content.contains('- [x]')).toList();
    }

    return results;
  }

  /// İçerik benzerliğine göre not arama (Jaccard Similarity)
  Future<List<Note>> searchBySimilarity(int noteId, {int limit = 10}) async {
    final sourceNote = await _repository.getNoteById(noteId);
    if (sourceNote == null) return [];

    final allNotes = await _repository.getAllNotes();
    final similarities = <Map<String, dynamic>>[];

    for (final note in allNotes) {
      if (note.id == noteId) continue;

      final similarity = _calculateContentSimilarity(sourceNote.content, note.content);
      if (similarity > 0.1) {
        similarities.add({
          'note': note,
          'similarity': similarity,
        });
      }
    }

    similarities.sort((a, b) => (b['similarity'] as double).compareTo(a['similarity'] as double));

    return similarities
        .take(limit)
        .map((item) => item['note'] as Note)
        .toList();
  }

  /// Arama kutusu için otomatik tamamlama önerileri
  Future<List<String>> getSearchSuggestions(String partialQuery) async {
    final normQuery = normalize(partialQuery);
    if (normQuery.length < 2) return [];

    final allNotes = await _repository.getAllNotes();
    final suggestions = <String>{};

    for (final note in allNotes) {
      // Başlık kelimeleri
      final titleWords = normalize(note.title).split(RegExp(r'\s+'));
      for (final word in titleWords) {
        if (word.startsWith(normQuery) && word.length > 2) {
          suggestions.add(word);
        }
      }

      // Etiket önerileri
      for (final tag in note.tags) {
        final cleanTag = normalize(tag).replaceAll('#', '');
        if (cleanTag.startsWith(normQuery)) {
          suggestions.add('#$cleanTag');
        }
      }

      if (suggestions.length >= 10) break;
    }

    return suggestions.toList();
  }

  /// Popüler arama terimleri
  Future<List<String>> getPopularSearchTerms({int limit = 20}) async {
    final allNotes = await _repository.getAllNotes();
    final termFrequency = <String, int>{};

    for (final note in allNotes) {
      // Başlık kelimeleri (+3 ağırlık)
      final titleWords = normalize(note.title).split(RegExp(r'\s+'));
      for (final word in titleWords) {
        if (word.length > 2 && !_stopWords.contains(word)) {
          termFrequency[word] = (termFrequency[word] ?? 0) + 3;
        }
      }

      // Etiketler (+5 ağırlık)
      for (final tag in note.tags) {
        final cleanTag = normalize(tag).replaceAll('#', '');
        if (cleanTag.isNotEmpty) {
          termFrequency['#$cleanTag'] = (termFrequency['#$cleanTag'] ?? 0) + 5;
        }
      }
    }

    final sorted = termFrequency.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return sorted.take(limit).map((e) => e.key).toList();
  }

  double _calculateContentSimilarity(String c1, String c2) {
    final words1 = normalize(c1).split(RegExp(r'\s+')).where((w) => w.length > 2 && !_stopWords.contains(w)).toSet();
    final words2 = normalize(c2).split(RegExp(r'\s+')).where((w) => w.length > 2 && !_stopWords.contains(w)).toSet();

    if (words1.isEmpty || words2.isEmpty) return 0.0;
    final intersection = words1.intersection(words2);
    final union = words1.union(words2);
    return intersection.length / union.length;
  }
}
