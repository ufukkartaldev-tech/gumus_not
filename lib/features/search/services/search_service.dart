import 'dart:isolate';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';

class SearchService {
  // Alaka Düzeyi (Relevance) Ağırlık Katsayıları (SRS Bölüm 11.1)
  static const int scoreExactTitle = 100;
  static const int scorePrefixTitle = 60;
  static const int scoreSubstringTitle = 50;
  static const int scoreFuzzyTitle = 20;
  static const int scoreExactTag = 40;
  static const int scoreSubstringTag = 30;
  static const int scoreFuzzyTag = 15;
  static const int scoreContentMatch = 5;

  // Zettelkasten Graf & Merkezilik Sabitleri (SRS Bölüm 11.1 & 16.1)
  static const int scoreSemanticBoost = 25; // Doğrudan komşu notlar (1-hop)
  static const int scoreCoCitation = 12; // Kardeş notlar (Co-Citation / Ortak Atıf)
  static const int scoreBacklinkBoost = 5; // Geri bağlantı (PageRank) katsayısı
  static const int maxRecencyBonus = 5; // Son güncellenen notlar için üstel azalım tavanı

  // Arka plan Isolate eşiği (SRS Bölüm 16.1)
  static const int isolateThreshold = 500;

  // Maksimum Levenshtein Mesafesi (Hata toleransı)
  static const int maxDistance = 2;

  static final RegExp _wikiLinkRegex = RegExp(r'\[\[([^\[\]]+)\]\]');

  // Stop Words (Boş Kelimeler) Listesi
  static const Set<String> stopWords = {
    've',
    'ile',
    'veya',
    'bir',
    'bu',
    'şu',
    'o',
    'mı',
    'mi',
    'da',
    'de',
    'ki',
    'ama',
    'fakat',
    'lakin',
    'için',
    'gibi',
    'kadar',
  };

  /// Ana Arama Fonksiyonu.
  /// Not sayısı [isolateThreshold] (500) sınırını aştığında ana UI iş parçacığını
  /// bloklamamak için hesaplamayı arka plan [Isolate]'ine devreder.
  static Future<List<Note>> searchNotes(
    String query,
    List<Note> allNotes,
  ) async {
    if (query.trim().isEmpty) return allNotes;

    if (!kIsWeb && allNotes.length > isolateThreshold) {
      return Isolate.run(() => searchNotesSync(query, allNotes));
    }

    return searchNotesSync(query, allNotes);
  }

  /// Senkron arama çekirdeği (hem doğrudan hem [Isolate.run] içinden çağrılabilir).
  static List<Note> searchNotesSync(
    String query,
    List<Note> allNotes, {
    int? referenceTimestampMs,
  }) {
    final normalizedQuery = query.toLowerCase().trim();
    if (normalizedQuery.isEmpty) return allNotes;
    if (allNotes.isEmpty) return const [];

    final isStopWord = stopWords.contains(normalizedQuery);
    final allowFuzzy = !isStopWord && normalizedQuery.length > 2;
    final queryLen = normalizedQuery.length;

    // Yeniden kullanılabilir Levenshtein tamponları (GC baskısını sıfırlar)
    var levV0 = Int32List(max(32, queryLen + 2));
    var levV1 = Int32List(max(32, queryLen + 2));

    final directScores = <int, int>{};
    final seedKeys = <int>[];

    for (int index = 0; index < allNotes.length; index++) {
      final note = allNotes[index];
      final int nodeKey = note.id ?? -(index + 1);

      int score = 0;
      final title = note.title.toLowerCase();

      // 1. BAŞLIK KONTROLLERİ (Tam -> Ön-Ek -> Alt-Dizge -> Bulanık)
      if (title == normalizedQuery) {
        score += scoreExactTitle;
      } else if (title.startsWith(normalizedQuery)) {
        score += scorePrefixTitle;
      } else if (title.contains(normalizedQuery)) {
        score += scoreSubstringTitle;
      } else if (allowFuzzy && title.isNotEmpty) {
        final words = title.split(' ');
        for (int w = 0; w < words.length; w++) {
          final word = words[w];
          if ((word.length - queryLen).abs() <= maxDistance) {
            if (word.length + 1 >= levV0.length) {
              levV0 = Int32List(word.length + 16);
              levV1 = Int32List(word.length + 16);
            }
            if (_levenshteinBounded(
                  word,
                  normalizedQuery,
                  levV0,
                  levV1,
                ) <=
                maxDistance) {
              score += scoreFuzzyTitle;
              break;
            }
          }
        }
      }

      // 2. ETİKET KONTROLLERİ
      final rawTags = note.tags;
      for (int t = 0; t < rawTags.length; t++) {
        final tag = rawTags[t].toLowerCase();
        if (tag == normalizedQuery) {
          score += scoreExactTag;
        } else if (tag.contains(normalizedQuery)) {
          score += scoreSubstringTag;
        } else if (allowFuzzy &&
            (tag.length - queryLen).abs() <= maxDistance) {
          if (tag.length + 1 >= levV0.length) {
            levV0 = Int32List(tag.length + 16);
            levV1 = Int32List(tag.length + 16);
          }
          if (_levenshteinBounded(tag, normalizedQuery, levV0, levV1) <=
              maxDistance) {
            score += scoreFuzzyTag;
          }
        }
      }

      // 3. İÇERİK KONTROLÜ (Logaritmik TF; şifreli notlar kesinlikle hariç)
      if (!note.isEncrypted && !isStopWord && note.content.isNotEmpty) {
        final contentLower = note.content.toLowerCase();
        final occurrences = _countOccurrences(contentLower, normalizedQuery);
        if (occurrences > 0) {
          score += (scoreContentMatch * (1.0 + log(occurrences))).round();
        }
      }

      if (score > 0) {
        directScores[nodeKey] = score;
        seedKeys.add(nodeKey);
      }
    }

    // Hiçbir çekirdek (seed) eşleşme yoksa graf taramasına gerek kalmadan çık
    if (seedKeys.isEmpty) {
      return const [];
    }

    // 4. ZETTELKASTEN SEMANTİK GRAF ANALİZİ (Komşular + Co-Citation Kardeş Notlar)
    final resultNodes = <int, Note>{};
    final titleToKey = <String, int>{};

    for (int index = 0; index < allNotes.length; index++) {
      final note = allNotes[index];
      final int nodeKey = note.id ?? -(index + 1);
      resultNodes[nodeKey] = note;
      final normalizedTitle = note.title.trim().toLowerCase();
      if (normalizedTitle.isNotEmpty) {
        titleToKey[normalizedTitle] = nodeKey;
      }
    }

    final outgoingKeys = <int, List<int>>{};
    final incomingKeys = <int, List<int>>{};

    for (int index = 0; index < allNotes.length; index++) {
      final note = allNotes[index];
      final int sourceKey = note.id ?? -(index + 1);

      if (note.isEncrypted || !note.content.contains('[[')) {
        continue;
      }

      final matches = _wikiLinkRegex.allMatches(note.content);
      List<int>? targets;
      for (final match in matches) {
        final rawTarget = match.group(1);
        if (rawTarget == null || rawTarget.isEmpty) continue;
        // [[Başlık|Takma Ad]] sözdizimini destekle (SRS Bölüm 8.2)
        final pipeIdx = rawTarget.indexOf('|');
        final cleanTitle =
            (pipeIdx == -1 ? rawTarget : rawTarget.substring(0, pipeIdx))
                .trim()
                .toLowerCase();
        if (cleanTitle.isEmpty) continue;

        final targetKey = titleToKey[cleanTitle];
        if (targetKey != null && targetKey != sourceKey) {
          targets ??= <int>[];
          if (!targets.contains(targetKey)) {
            targets.add(targetKey);
            (incomingKeys[targetKey] ??= <int>[]).add(sourceKey);
          }
        }
      }
      if (targets != null) {
        outgoingKeys[sourceKey] = targets;
      }
    }

    final semanticScores = <int, int>{};

    for (int i = 0; i < seedKeys.length; i++) {
      final seedKey = seedKeys[i];
      final siblingsForSeed = <int>{};

      // 4a. Doğrudan giden komşular (seed -> target)
      final outTargets = outgoingKeys[seedKey];
      if (outTargets != null) {
        for (int t = 0; t < outTargets.length; t++) {
          final targetKey = outTargets[t];
          semanticScores[targetKey] =
              (semanticScores[targetKey] ?? 0) + scoreSemanticBoost;

          // Bibliographic Coupling: seed ile aynı hedef nota atıf yapan kardeşler
          final coCitingSources = incomingKeys[targetKey];
          if (coCitingSources != null) {
            for (int c = 0; c < coCitingSources.length; c++) {
              final siblingKey = coCitingSources[c];
              if (siblingKey != seedKey && siblingKey != targetKey) {
                siblingsForSeed.add(siblingKey);
              }
            }
          }
        }
      }

      // 4b. Doğrudan gelen komşular (parent -> seed)
      final inSources = incomingKeys[seedKey];
      if (inSources != null) {
        for (int s = 0; s < inSources.length; s++) {
          final parentKey = inSources[s];
          semanticScores[parentKey] =
              (semanticScores[parentKey] ?? 0) + scoreSemanticBoost;

          // Co-Citation: aynı üst/indeks not tarafından birlikte atıf alan kardeşler
          final parentTargets = outgoingKeys[parentKey];
          if (parentTargets != null) {
            for (int p = 0; p < parentTargets.length; p++) {
              final siblingKey = parentTargets[p];
              if (siblingKey != seedKey && siblingKey != parentKey) {
                siblingsForSeed.add(siblingKey);
              }
            }
          }
        }
      }

      // 4c. Kardeş notlara Co-Citation puanı ekle
      for (final siblingKey in siblingsForSeed) {
        semanticScores[siblingKey] =
            (semanticScores[siblingKey] ?? 0) + scoreCoCitation;
      }
    }

    // 5. TÜM PUANLARI BİRLEŞTİR (Keyword + Semantik + Geri Bağlantı + Yenilik)
    final nowMs = referenceTimestampMs ?? DateTime.now().millisecondsSinceEpoch;
    final candidateKeys = <int>{...directScores.keys, ...semanticScores.keys};
    final scoredResults = <_ScoredNoteEntry>[];

    for (final key in candidateKeys) {
      final note = resultNodes[key];
      if (note == null) continue;

      final direct = directScores[key] ?? 0;
      final semantic = semanticScores[key] ?? 0;
      int totalScore = direct + semantic;
      if (totalScore <= 0) continue;

      // Geri bağlantı (PageRank) katkısı: yalnızca aday havuzuna giren notlara uygulanır
      final backlinkCount = incomingKeys[key]?.length ?? 0;
      if (backlinkCount > 0) {
        totalScore += backlinkCount * scoreBacklinkBoost;
      }

      // Yenilik (Recency) üstel azalım katkısı (yarı ömür ~30 gün)
      if (note.updatedAt > 0 && note.updatedAt <= nowMs) {
        final ageDays = (nowMs - note.updatedAt) / 86400000.0;
        if (ageDays < 180.0) {
          totalScore += (maxRecencyBonus * exp(-ageDays / 30.0)).round();
        }
      }

      scoredResults.add(
        _ScoredNoteEntry(
          note: note,
          score: totalScore,
          hasDirectMatch: direct > 0,
        ),
      );
    }

    // Doğrudan arama terimiyle eşleşen (seed) notlar, yalnızca graf komşuluğu /
    // Co-Citation ile gelen notların önünde sıralanır.
    scoredResults.sort((a, b) {
      if (a.hasDirectMatch != b.hasDirectMatch) {
        return a.hasDirectMatch ? -1 : 1;
      }
      final cmp = b.score.compareTo(a.score);
      if (cmp != 0) return cmp;
      return b.note.updatedAt.compareTo(a.note.updatedAt);
    });

    return [for (final entry in scoredResults) entry.note];
  }

  static int _countOccurrences(String text, String pattern) {
    int count = 0;
    int index = text.indexOf(pattern);
    final step = pattern.length;
    while (index != -1) {
      count++;
      index = text.indexOf(pattern, index + step);
    }
    return count;
  }

  /// Sıfır bellek tahsisli Levenshtein düzenleme mesafesi hesaplayıcı.
  static int _levenshteinBounded(
    String s1,
    String s2,
    Int32List v0,
    Int32List v1,
  ) {
    if (s1 == s2) return 0;
    final len1 = s1.length;
    final len2 = s2.length;
    if (len1 == 0) return len2;
    if (len2 == 0) return len1;

    for (int j = 0; j <= len2; j++) {
      v0[j] = j;
    }

    for (int i = 0; i < len1; i++) {
      v1[0] = i + 1;
      int rowMin = v1[0];
      final c1 = s1.codeUnitAt(i);

      for (int j = 0; j < len2; j++) {
        final cost = (c1 == s2.codeUnitAt(j)) ? 0 : 1;
        final deletion = v0[j + 1] + 1;
        final insertion = v1[j] + 1;
        final substitution = v0[j] + cost;
        final cell = min(insertion, min(deletion, substitution));
        v1[j + 1] = cell;
        if (cell < rowMin) rowMin = cell;
      }

      if (rowMin > maxDistance) {
        return maxDistance + 1;
      }

      for (int j = 0; j <= len2; j++) {
        v0[j] = v1[j];
      }
    }

    return v0[len2];
  }
}

class _ScoredNoteEntry {
  const _ScoredNoteEntry({
    required this.note,
    required this.score,
    required this.hasDirectMatch,
  });

  final Note note;
  final int score;
  final bool hasDirectMatch;
}
