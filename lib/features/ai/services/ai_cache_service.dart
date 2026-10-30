import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Privacy-preserving AI response cache using **64-bit SimHash** (Charikar's
/// Locality-Sensitive Hashing) and **SHA-256** content digests.
///
/// ### Security & Privacy Guarantees:
/// - **Zero Plaintext Persistence**: Raw note bodies are NEVER written to
///   `SharedPreferences` or disk by this service. Only fixed-length cryptographic
///   hashes (`SHA-256`) and 64-bit locality-sensitive signatures (`SimHash`) are stored.
/// - **Encrypted Note Protection**: Callers can pass `persistToDisk: false` for
///   encrypted notes so that AI responses (summaries/tags) reside strictly in
///   volatile RAM and are wiped when the session ends.
/// - **True Semantic/Lexical Similarity**: Minor typo fixes or whitespace edits
///   are detected by computing the Hamming distance between 64-bit SimHash
///   fingerprints of normalized word/character shingles, rather than naive
///   string length comparisons.
class AiCacheService {
  static const String _legacyPrefixText = 'ai_cache_text_';
  static const String _prefixSha256 = 'ai_cache_sha256_';
  static const String _prefixSimHash = 'ai_cache_simhash_';
  static const String _prefixResult = 'ai_cache_result_';

  /// Maximum Hamming distance (out of 64 bits) allowed to consider two texts
  /// near-duplicates (~94% structural/lexical similarity).
  static const int defaultMaxHammingDistance = 4;

  final int maxHammingDistance;

  /// Volatile in-memory cache for encrypted notes (`persistToDisk: false`)
  /// and fast L1 lookup.
  final Map<String, _CacheEntry> _memoryCache = {};

  AiCacheService({this.maxHammingDistance = defaultMaxHammingDistance});

  /// Retrieves a cached AI response if the [currentText] matches the previous
  /// content either exactly (via SHA-256) or within [maxHammingDistance] bits
  /// on a 64-bit SimHash fingerprint.
  Future<String?> getCached(
    String type,
    String noteId,
    String currentText, {
    bool allowDiskRead = true,
  }) async {
    final normalized = _normalizeText(currentText);
    if (normalized.isEmpty) return null;

    final currentSha = computeSha256(normalized);
    final currentSimHash = computeSimHash64(normalized);
    final cacheKey = '${type}_$noteId';

    // 1. Check L1 in-memory cache first
    final memEntry = _memoryCache[cacheKey];
    if (memEntry != null) {
      if (_isMatch(
        currentSha: currentSha,
        currentSimHash: currentSimHash,
        cachedSha: memEntry.sha256,
        cachedSimHash: memEntry.simHash,
      )) {
        return memEntry.result;
      }
    }

    if (!allowDiskRead) return null;

    // 2. Check L2 persistent cache (SharedPreferences)
    final prefs = await SharedPreferences.getInstance();

    // Purge any legacy plaintext cache entry left over from older versions
    if (prefs.containsKey('$_legacyPrefixText$cacheKey')) {
      await prefs.remove('$_legacyPrefixText$cacheKey');
    }

    final cachedSha = prefs.getString('$_prefixSha256$cacheKey');
    final cachedSimHashHex = prefs.getString('$_prefixSimHash$cacheKey');
    final cachedResult = prefs.getString('$_prefixResult$cacheKey');

    if (cachedSha == null || cachedSimHashHex == null || cachedResult == null) {
      return null;
    }

    final cachedSimHashBig = BigInt.tryParse(cachedSimHashHex, radix: 16);
    if (cachedSimHashBig == null) return null;
    final cachedSimHash = cachedSimHashBig.toSigned(64).toInt();

    if (_isMatch(
      currentSha: currentSha,
      currentSimHash: currentSimHash,
      cachedSha: cachedSha,
      cachedSimHash: cachedSimHash,
    )) {
      // Populate L1 cache
      _memoryCache[cacheKey] = _CacheEntry(
        sha256: cachedSha,
        simHash: cachedSimHash,
        result: cachedResult,
      );
      return cachedResult;
    }

    return null;
  }

  /// Stores the AI [result] alongside the [text]'s SHA-256 digest and 64-bit
  /// SimHash signature. Never stores raw [text].
  ///
  /// When [persistToDisk] is `false` (e.g. for encrypted vault notes), the
  /// entry is kept strictly in volatile RAM and any existing disk entry for
  /// [noteId] is erased.
  Future<void> setCached(
    String type,
    String noteId,
    String text,
    String result, {
    bool persistToDisk = true,
  }) async {
    final normalized = _normalizeText(text);
    final sha = computeSha256(normalized);
    final simHash = computeSimHash64(normalized);
    final cacheKey = '${type}_$noteId';

    _memoryCache[cacheKey] = _CacheEntry(
      sha256: sha,
      simHash: simHash,
      result: result,
    );

    final prefs = await SharedPreferences.getInstance();
    // Always ensure legacy plaintext key is removed
    await prefs.remove('$_legacyPrefixText$cacheKey');

    if (!persistToDisk) {
      await prefs.remove('$_prefixSha256$cacheKey');
      await prefs.remove('$_prefixSimHash$cacheKey');
      await prefs.remove('$_prefixResult$cacheKey');
      return;
    }

    await prefs.setString('$_prefixSha256$cacheKey', sha);
    await prefs.setString(
      '$_prefixSimHash$cacheKey',
      BigInt.from(simHash).toUnsigned(64).toRadixString(16).padLeft(16, '0'),
    );
    await prefs.setString('$_prefixResult$cacheKey', result);
  }

  /// Clears in-memory cache and optionally persistent cache for a note.
  Future<void> invalidateNote(String noteId) async {
    _memoryCache.removeWhere((key, _) => key.endsWith('_$noteId'));
    final prefs = await SharedPreferences.getInstance();
    for (final type in const ['summary', 'tags']) {
      final cacheKey = '${type}_$noteId';
      await prefs.remove('$_legacyPrefixText$cacheKey');
      await prefs.remove('$_prefixSha256$cacheKey');
      await prefs.remove('$_prefixSimHash$cacheKey');
      await prefs.remove('$_prefixResult$cacheKey');
    }
  }

  bool _isMatch({
    required String currentSha,
    required int currentSimHash,
    required String cachedSha,
    required int cachedSimHash,
  }) {
    if (currentSha == cachedSha) return true;
    final distance = hammingDistance64(currentSimHash, cachedSimHash);
    return distance <= maxHammingDistance;
  }

  static String _normalizeText(String input) {
    return input.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Returns the hex-encoded SHA-256 digest of [text].
  @visibleForTesting
  static String computeSha256(String text) {
    return sha256.convert(utf8.encode(text)).toString();
  }

  /// Computes a 64-bit Charikar SimHash fingerprint over overlapping character
  /// 3-grams (shingles) and word tokens.
  ///
  /// Unlike naive length checks, completely different texts of identical length
  /// produce orthogonal bit vectors (~32 bits Hamming distance), while minor
  /// typo corrections flip at most 1–4 bits.
  @visibleForTesting
  static int computeSimHash64(String text) {
    final normalized = _normalizeText(text);
    if (normalized.isEmpty) return 0;

    final weights = List<int>.filled(64, 0);
    final features = _extractFeatures(normalized);

    for (final feature in features) {
      final hash64 = _featureHash64(feature);
      for (var bit = 0; bit < 64; bit++) {
        if (((hash64 >>> bit) & 1) == 1) {
          weights[bit] += 1;
        } else {
          weights[bit] -= 1;
        }
      }
    }

    var fingerprint = 0;
    for (var bit = 0; bit < 64; bit++) {
      if (weights[bit] > 0) {
        fingerprint |= (1 << bit);
      }
    }
    return fingerprint;
  }

  /// Computes the Hamming distance (number of differing bits) between two
  /// 64-bit integers.
  @visibleForTesting
  static int hammingDistance64(int a, int b) {
    var xor = a ^ b;
    var count = 0;
    for (var i = 0; i < 64; i++) {
      count += (xor >>> i) & 1;
    }
    return count;
  }

  /// Extracts word tokens and character 3-gram shingles for robust LSH sensitivity.
  static List<String> _extractFeatures(String normalized) {
    final features = <String>[];
    final words = normalized.split(' ');
    for (final word in words) {
      if (word.isNotEmpty) {
        features.add('w:$word');
      }
    }
    // Character 3-grams capture sub-word edits (typos)
    if (normalized.length < 3) {
      features.add('c:$normalized');
    } else {
      for (var i = 0; i <= normalized.length - 3; i++) {
        features.add('c:${normalized.substring(i, i + 3)}');
      }
    }
    return features;
  }

  /// Extracts the first 64 bits (8 bytes) of SHA-256 for uniform feature hashing.
  static int _featureHash64(String input) {
    final digestBytes = sha256.convert(utf8.encode(input)).bytes;
    final data = ByteData.sublistView(Uint8List.fromList(digestBytes), 0, 8);
    return data.getInt64(0);
  }
}

class _CacheEntry {
  final String sha256;
  final int simHash;
  final String result;

  const _CacheEntry({
    required this.sha256,
    required this.simHash,
    required this.result,
  });
}
