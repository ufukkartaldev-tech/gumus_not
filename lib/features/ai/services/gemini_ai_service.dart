import 'dart:async';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'iai_service.dart';
import '../models/ai_config.dart';
import '../models/ai_exception.dart';

class GeminiAiService implements IAiService {
  final GenerativeModel _model;
  final String _apiKey;

  GeminiAiService(AiConfig config, {int maxOutputTokens = IAiService.defaultMaxOutputTokens})
      : _apiKey = config.apiKey?.trim() ?? '',
        _model = GenerativeModel(
          model: config.modelName?.isNotEmpty == true
              ? config.modelName!.trim()
              : 'gemini-1.5-flash',
          apiKey: config.apiKey?.trim() ?? '',
          generationConfig: GenerationConfig(maxOutputTokens: maxOutputTokens),
        );

  AiException _mapError(Object e) {
    if (e is AiException) return e;
    if (e is SocketException) return AiException.network(e.message);
    if (e is TimeoutException) {
      return const AiException(
        'Gemini isteği zaman aşımına uğradı (30 saniye). Lütfen internet bağlantınızı kontrol edin.',
      );
    }
    if (e is GenerativeAIException) {
      final msg = e.message.toLowerCase();
      if (msg.contains('api_key') ||
          msg.contains('invalid') ||
          msg.contains('unauthorized')) {
        return AiException.invalidApiKey();
      } else if (msg.contains('quota') ||
          msg.contains('resource_exhausted') ||
          msg.contains('429')) {
        return AiException.rateLimited();
      }
      return AiException('Gemini servisi hatası: ${e.message}');
    }
    final errStr = e.toString();
    if (errStr.contains('SocketException') ||
        errStr.contains('Failed host lookup')) {
      return AiException.network();
    }
    return AiException(
      'Gemini işlemi sırasında beklenmeyen bir hata oluştu: $e',
    );
  }

  Future<String> _safeGenerate(String prompt) async {
    if (_apiKey.isEmpty) {
      throw AiException.missingApiKey(
        'Gemini API anahtarı eksik. Lütfen Ayarlar > Yapay Zeka ekranından geçerli bir anahtar girin.',
      );
    }

    try {
      final response = await _model
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 30));

      final text = response.text?.trim() ?? '';
      if (text.isEmpty) {
        throw const AiException(
          'Gemini yanıtı boş döndü veya içerik güvenlik filtresine takıldı.',
        );
      }
      return text;
    } catch (e) {
      throw _mapError(e);
    }
  }

  Stream<String> _safeStreamGenerate(String prompt) async* {
    if (_apiKey.isEmpty) {
      throw AiException.missingApiKey(
        'Gemini API anahtarı eksik. Lütfen Ayarlar > Yapay Zeka ekranından geçerli bir anahtar girin.',
      );
    }

    var emittedAny = false;
    try {
      final responseStream = _model.generateContentStream([Content.text(prompt)]);
      await for (final chunk in responseStream.timeout(const Duration(seconds: 30))) {
        final piece = chunk.text;
        if (piece != null && piece.isNotEmpty) {
          emittedAny = true;
          yield piece;
        }
      }
      if (!emittedAny) {
        throw const AiException(
          'Gemini yanıtı boş döndü veya içerik güvenlik filtresine takıldı.',
        );
      }
    } catch (e) {
      throw _mapError(e);
    }
  }

  @override
  Future<String> generateSummary(String text) async {
    final compacted = IAiService.compactContextWindow(text);
    final prompt =
        "Aşağıdaki teknik notu/dokümanı ana noktalarını ve kod/mimari bağlamını koruyarak net şekilde özetle:\n\n$compacted";
    return await _safeGenerate(prompt);
  }

  @override
  Stream<String> streamSummary(String text) {
    final compacted = IAiService.compactContextWindow(text);
    final prompt =
        "Aşağıdaki teknik notu/dokümanı ana noktalarını ve kod/mimari bağlamını koruyarak net şekilde özetle:\n\n$compacted";
    return _safeStreamGenerate(prompt);
  }

  @override
  Future<List<String>> suggestTags(String text) async {
    final compacted = IAiService.compactContextWindow(text);
    final prompt =
        "Aşağıdaki metin için sadece virgülle ayrılmış tek kelimelik etiketler öner. Markdown veya başka açıklama kullanma:\n\n$compacted";
    final raw = await _safeGenerate(prompt);
    return raw
        .split(',')
        .map((e) => e.trim().replaceAll('#', ''))
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  Future<String> customPrompt(String prompt, String content) async {
    final compacted = IAiService.compactContextWindow(content);
    return await _safeGenerate("$prompt\n\n$compacted");
  }

  @override
  Stream<String> streamCustomPrompt(String prompt, String content) {
    final compacted = IAiService.compactContextWindow(content);
    return _safeStreamGenerate("$prompt\n\n$compacted");
  }

  @override
  void dispose() {}
}
