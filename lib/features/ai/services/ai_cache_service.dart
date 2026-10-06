import 'package:shared_preferences/shared_preferences.dart';

class AiCacheService {
  static const String _prefixText = 'ai_cache_text_';
  static const String _prefixResult = 'ai_cache_result_';

  /// %5'lik bir tolerans (Fuzzy Caching) ile önbelleği kontrol eder.
  /// Eğer aynı not üzerinde yapılan değişiklik %5'ten az ise eski sonucu döndürür.
  Future<String?> getCached(String type, String noteId, String currentText) async {
    final prefs = await SharedPreferences.getInstance();
    final lastText = prefs.getString('$_prefixText${type}_$noteId');
    final lastResult = prefs.getString('$_prefixResult${type}_$noteId');

    if (lastText != null && lastResult != null) {
      final diff = (currentText.length - lastText.length).abs();
      final tolerance = lastText.length * 0.05; // %5 Tolerans Sınırı

      // Metin uzunluğu %5'ten daha az değişmişse, bu ufak bir düzeltmedir (harf hatası vs.)
      if (diff <= tolerance) {
        return lastResult; // API'ye gitme, cebinden token yakma! Eski sonucu ver.
      }
    }
    return null; // Değişim %5'ten büyük, yeni özet çıkarılmalı.
  }

  /// Yeni üretilen sonucu ve o anki referans metni kaydeder.
  Future<void> setCached(String type, String noteId, String text, String result) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_prefixText${type}_$noteId', text);
    await prefs.setString('$_prefixResult${type}_$noteId', result);
  }
}
