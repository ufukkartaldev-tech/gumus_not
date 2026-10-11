import 'package:flutter/material.dart';
import '../models/ai_config.dart';
import '../models/ai_exception.dart';
import '../models/ai_provider_type.dart';
import '../services/iai_service.dart';
import '../services/gemini_ai_service.dart';
import '../services/openai_compatible_service.dart';
import '../services/secure_key_storage.dart';
import '../services/ai_cache_service.dart';

class AiProvider extends ChangeNotifier {
  final SecureKeyStorage _storage;
  final AiCacheService _cacheService;

  AiProvider({
    SecureKeyStorage? storage,
    AiCacheService? cacheService,
  })  : _storage = storage ?? SecureKeyStorage(),
        _cacheService = cacheService ?? AiCacheService();

  AiConfig _config = AiConfig(providerType: AiProviderType.none);
  IAiService? _activeService;
  bool _isLoading = false;
  String? _lastError;

  AiConfig get config => _config;
  IAiService? get activeService => _activeService;
  bool get isAiEnabled =>
      _config.providerType != AiProviderType.none && _activeService != null;
  bool get isLoading => _isLoading;
  String? get lastError => _lastError;

  void clearError() {
    _lastError = null;
    notifyListeners();
  }

  Future<void> loadConfig() async {
    _config = await _storage.loadConfig();
    _initializeService();
    notifyListeners();
  }

  Future<void> saveConfig(AiConfig newConfig) async {
    await _storage.saveConfig(newConfig);
    _config = newConfig;
    _initializeService();
    _lastError = null;
    notifyListeners();
  }

  void _initializeService() {
    if (_config.providerType == AiProviderType.none ||
        _config.apiKey == null ||
        _config.apiKey!.trim().isEmpty) {
      _activeService = null;
      return;
    }

    try {
      if (_config.providerType == AiProviderType.gemini) {
        _activeService = GeminiAiService(_config);
      } else if (_config.providerType == AiProviderType.openAiCompatible) {
        _activeService = OpenAiCompatibleService(_config);
      }
    } catch (e) {
      debugPrint("AI Servisi başlatılamadı: $e");
      _activeService = null;
      _lastError = 'AI Servisi başlatılamadı: $e';
    }
  }

  /// Belirtilen veya mevcut yapılandırma ile bağlantıyı test eder.
  /// Başarılıysa `null`, hata varsa kullanıcı dostu hata mesajı döner.
  Future<String?> testConnection([AiConfig? customConfig]) async {
    final targetConfig = customConfig ?? _config;
    if (targetConfig.providerType == AiProviderType.none) {
      return 'Lütfen bir AI sağlayıcısı seçin.';
    }
    if (targetConfig.apiKey == null || targetConfig.apiKey!.trim().isEmpty) {
      return 'Lütfen bir API anahtarı girin.';
    }

    try {
      IAiService testService;
      if (targetConfig.providerType == AiProviderType.gemini) {
        testService = GeminiAiService(targetConfig);
      } else {
        testService = OpenAiCompatibleService(targetConfig);
      }

      await testService.customPrompt('Test connection. Respond with: OK', 'Hello');
      return null;
    } on AiException catch (e) {
      return e.message;
    } catch (e) {
      return 'Bağlantı testi başarısız oldu: $e';
    }
  }

  // --- Caching Proxy Methods (Fuzzy %5 Tolerance) ---

  Future<String> getSummary(String text, {required String noteId}) async {
    if (!isAiEnabled) {
      throw AiException.unconfigured(
        'AI servisi kapalı veya yapılandırılmamış. Lütfen Ayarlar > Yapay Zeka ekranından yapılandırın.',
      );
    }

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final cached = await _cacheService.getCached('summary', noteId, text);
      if (cached != null) {
        debugPrint("AI Cache Hit (Fuzzy %5): Özet önbellekten getirildi.");
        return cached;
      }

      final result = await _activeService!.generateSummary(text);
      await _cacheService.setCached('summary', noteId, text, result);
      return result;
    } on AiException catch (e) {
      _lastError = e.message;
      rethrow;
    } catch (e) {
      final message = 'Özet oluşturulurken beklenmeyen bir hata oluştu: $e';
      _lastError = message;
      throw AiException(message);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<List<String>> getTags(String text, {required String noteId}) async {
    if (!isAiEnabled) {
      throw AiException.unconfigured(
        'AI servisi kapalı veya yapılandırılmamış. Lütfen Ayarlar > Yapay Zeka ekranından yapılandırın.',
      );
    }

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final cached = await _cacheService.getCached('tags', noteId, text);
      if (cached != null) {
        debugPrint("AI Cache Hit (Fuzzy %5): Etiketler önbellekten getirildi.");
        return cached.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }

      final result = await _activeService!.suggestTags(text);
      await _cacheService.setCached('tags', noteId, text, result.join(','));
      return result;
    } on AiException catch (e) {
      _lastError = e.message;
      rethrow;
    } catch (e) {
      final message = 'Etiket önerisi alınırken beklenmeyen bir hata oluştu: $e';
      _lastError = message;
      throw AiException(message);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
