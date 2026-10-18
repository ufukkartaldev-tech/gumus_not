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
    _activeService?.dispose();
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

  @override
  void dispose() {
    _activeService?.dispose();
    super.dispose();
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

    IAiService? testService;
    try {
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
    } finally {
      testService?.dispose();
    }
  }

  // --- Caching Proxy Methods (SimHash LSH + SHA-256) ---

  /// Streams the summary token-by-token while transparently checking and
  /// populating the privacy-preserving SimHash LSH cache.
  Stream<String> streamSummary(
    String text, {
    required String noteId,
    bool isEncrypted = false,
  }) async* {
    if (!isAiEnabled) {
      throw AiException.unconfigured(
        'AI servisi kapalı veya yapılandırılmamış. Lütfen Ayarlar > Yapay Zeka ekranından yapılandırın.',
      );
    }

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final cached = await _cacheService.getCached(
        'summary',
        noteId,
        text,
        allowDiskRead: !isEncrypted,
      );
      if (cached != null) {
        debugPrint("AI Cache Hit (SimHash LSH): Özet önbellekten getirildi.");
        yield cached;
        return;
      }

      final buffer = StringBuffer();
      await for (final chunk in _activeService!.streamSummary(text)) {
        buffer.write(chunk);
        yield chunk;
      }

      final fullResult = buffer.toString().trim();
      if (fullResult.isNotEmpty) {
        await _cacheService.setCached(
          'summary',
          noteId,
          text,
          fullResult,
          persistToDisk: !isEncrypted,
        );
      }
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

  Future<String> getSummary(
    String text, {
    required String noteId,
    bool isEncrypted = false,
  }) async {
    if (!isAiEnabled) {
      throw AiException.unconfigured(
        'AI servisi kapalı veya yapılandırılmamış. Lütfen Ayarlar > Yapay Zeka ekranından yapılandırın.',
      );
    }

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final cached = await _cacheService.getCached(
        'summary',
        noteId,
        text,
        allowDiskRead: !isEncrypted,
      );
      if (cached != null) {
        debugPrint("AI Cache Hit (SimHash LSH): Özet önbellekten getirildi.");
        return cached;
      }

      final result = await _activeService!.generateSummary(text);
      await _cacheService.setCached(
        'summary',
        noteId,
        text,
        result,
        persistToDisk: !isEncrypted,
      );
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

  Future<List<String>> getTags(
    String text, {
    required String noteId,
    bool isEncrypted = false,
  }) async {
    if (!isAiEnabled) {
      throw AiException.unconfigured(
        'AI servisi kapalı veya yapılandırılmamış. Lütfen Ayarlar > Yapay Zeka ekranından yapılandırın.',
      );
    }

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    try {
      final cached = await _cacheService.getCached(
        'tags',
        noteId,
        text,
        allowDiskRead: !isEncrypted,
      );
      if (cached != null) {
        debugPrint("AI Cache Hit (SimHash LSH): Etiketler önbellekten getirildi.");
        return cached.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      }

      final result = await _activeService!.suggestTags(text);
      await _cacheService.setCached(
        'tags',
        noteId,
        text,
        result.join(','),
        persistToDisk: !isEncrypted,
      );
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

  /// Streams a custom or developer-specific prompt response token-by-token,
  /// optionally caching the result under [cacheActionKey] via SimHash LSH.
  Stream<String> streamCustomPrompt(
    String prompt,
    String content, {
    required String noteId,
    String? cacheActionKey,
    bool isEncrypted = false,
  }) async* {
    if (!isAiEnabled) {
      throw AiException.unconfigured(
        'AI servisi kapalı veya yapılandırılmamış. Lütfen Ayarlar > Yapay Zeka ekranından yapılandırın.',
      );
    }

    _isLoading = true;
    _lastError = null;
    notifyListeners();

    final cacheInput = '$prompt\n---\n$content';

    try {
      if (cacheActionKey != null) {
        final cached = await _cacheService.getCached(
          cacheActionKey,
          noteId,
          cacheInput,
          allowDiskRead: !isEncrypted,
        );
        if (cached != null) {
          debugPrint('AI Cache Hit (SimHash LSH): $cacheActionKey önbellekten getirildi.');
          yield cached;
          return;
        }
      }

      final buffer = StringBuffer();
      await for (final chunk in _activeService!.streamCustomPrompt(prompt, content)) {
        buffer.write(chunk);
        yield chunk;
      }

      final fullResult = buffer.toString().trim();
      if (cacheActionKey != null && fullResult.isNotEmpty) {
        await _cacheService.setCached(
          cacheActionKey,
          noteId,
          cacheInput,
          fullResult,
          persistToDisk: !isEncrypted,
        );
      }
    } on AiException catch (e) {
      _lastError = e.message;
      rethrow;
    } catch (e) {
      final message = 'AI komutu çalıştırılırken beklenmeyen bir hata oluştu: $e';
      _lastError = message;
      throw AiException(message);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Explains code or technical architecture, including algorithmic complexity
  /// and potential edge cases.
  Stream<String> streamCodeExplanation(
    String codeOrText, {
    required String noteId,
    bool isEncrypted = false,
  }) {
    const prompt =
        'Sen kıdemli bir yazılım mimarısın. Aşağıdaki kod parçasını veya teknik metni Türkçe olarak analiz et:\n'
        '1. Ne yaptığını adım adım açıkla.\n'
        '2. Varsa zaman ve bellek karmaşıklığını (Big-O) belirt.\n'
        '3. Olası uç durumları (edge-cases), güvenlik veya performans risklerini maddeler halinde yaz.';
    return streamCustomPrompt(
      prompt,
      codeOrText,
      noteId: noteId,
      cacheActionKey: 'explain_code',
      isEncrypted: isEncrypted,
    );
  }

  /// Refactors code according to Clean Code, SOLID, and idiomatic best practices.
  Stream<String> streamCodeRefactor(
    String codeOrText, {
    required String noteId,
    bool isEncrypted = false,
  }) {
    const prompt =
        'Sen kıdemli bir yazılım mühendisisin. Aşağıdaki kodu Clean Code, SOLID prensipleri, '
        'tip güvenliği ve performans açısından refactor et. Önce iyileştirilmiş kodu Markdown kod bloğu '
        'içinde ver, ardından yaptığın temel değişiklikleri kısaca Türkçe maddeler halinde açıkla.';
    return streamCustomPrompt(
      prompt,
      codeOrText,
      noteId: noteId,
      cacheActionKey: 'refactor_code',
      isEncrypted: isEncrypted,
    );
  }

  /// Generates structured technical documentation for functions, classes, or APIs.
  Stream<String> streamTechnicalDocs(
    String codeOrText, {
    required String noteId,
    bool isEncrypted = false,
  }) {
    const prompt =
        'Aşağıdaki kod veya teknik yapı için profesyonel Türkçe Markdown teknik dokümantasyonu üret. '
        'Mimari amaç, parametreler/girdiler, dönüş değerleri, örnek kullanım (kod bloğu ile) '
        've dikkat edilmesi gereken kısıtları içersin.';
    return streamCustomPrompt(
      prompt,
      codeOrText,
      noteId: noteId,
      cacheActionKey: 'generate_docs',
      isEncrypted: isEncrypted,
    );
  }
}
