import 'package:flutter/material.dart';
import '../models/ai_config.dart';
import '../models/ai_provider_type.dart';
import '../services/iai_service.dart';
import '../services/gemini_ai_service.dart';
import '../services/openai_compatible_service.dart';
import '../services/secure_key_storage.dart';

import '../services/ai_cache_service.dart';

class AiProvider extends ChangeNotifier {
  final SecureKeyStorage _storage = SecureKeyStorage();
  final AiCacheService _cacheService = AiCacheService();
  
  AiConfig _config = AiConfig(providerType: AiProviderType.none);
  IAiService? _activeService;

  AiConfig get config => _config;
  IAiService? get activeService => _activeService;
  bool get isAiEnabled => _config.providerType != AiProviderType.none && _activeService != null;

  Future<void> loadConfig() async {
    _config = await _storage.loadConfig();
    _initializeService();
    notifyListeners();
  }

  Future<void> saveConfig(AiConfig newConfig) async {
    await _storage.saveConfig(newConfig);
    _config = newConfig;
    _initializeService();
    notifyListeners();
  }

  void _initializeService() {
    if (_config.providerType == AiProviderType.none || _config.apiKey == null || _config.apiKey!.isEmpty) {
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
    }
  }

  // --- Caching Proxy Methods (Fuzzy %5 Tolerance) ---

  Future<String> getSummary(String text, {required String noteId}) async {
    if (_activeService == null) throw Exception("AI kapalı veya yapılandırılmamış.");
    
    final cached = await _cacheService.getCached('summary', noteId, text);
    if (cached != null) {
      debugPrint("AI Cache Hit (Fuzzy %5): Özet önbellekten getirildi.");
      return cached;
    }

    final result = await _activeService!.generateSummary(text);
    await _cacheService.setCached('summary', noteId, text, result);
    return result;
  }

  Future<List<String>> getTags(String text, {required String noteId}) async {
    if (_activeService == null) throw Exception("AI kapalı veya yapılandırılmamış.");
    
    final cached = await _cacheService.getCached('tags', noteId, text);
    if (cached != null) {
      debugPrint("AI Cache Hit (Fuzzy %5): Etiketler önbellekten getirildi.");
      return cached.split(',');
    }

    final result = await _activeService!.suggestTags(text);
    await _cacheService.setCached('tags', noteId, text, result.join(','));
    return result;
  }
}
