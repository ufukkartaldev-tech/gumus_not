import 'dart:convert';
import 'package:crypto/crypto.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AiCacheService {
  static const String _prefix = 'ai_cache_';

  /// Metnin ve işlem türünün (özet/etiket) matematiksel parmak izini çıkarır
  String _generateHash(String type, String text) {
    final bytes = utf8.encode(type + text);
    return sha256.convert(bytes).toString();
  }

  /// Hafızada bu parmak izine ait bir sonuç var mı kontrol eder
  Future<String?> getCached(String type, String text) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefix + _generateHash(type, text);
    return prefs.getString(key);
  }

  /// API'den gelen sonucu bu parmak iziyle hafızaya kaydeder
  Future<void> setCached(String type, String text, String result) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _prefix + _generateHash(type, text);
    await prefs.setString(key, result);
  }
}
