import 'dart:async';
import 'dart:io';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'iai_service.dart';
import '../models/ai_config.dart';
import '../models/ai_exception.dart';

class GeminiAiService implements IAiService {
  final GenerativeModel _model;
  final String _apiKey;

  GeminiAiService(AiConfig config)
      : _apiKey = config.apiKey?.trim() ?? '',
        _model = GenerativeModel(
          model: config.modelName?.isNotEmpty == true ? config.modelName!.trim() : 'gemini-1.5-flash',
          apiKey: config.apiKey?.trim() ?? '',
          generationConfig: GenerationConfig(maxOutputTokens: 250),
        );

  Future<String> _safeGenerate(String prompt) async {
    if (_apiKey.isEmpty) {
      throw AiException.missingApiKey('Gemini API anahtarı eksik. Lütfen Ayarlar > Yapay Zeka ekranından geçerli bir anahtar girin.');
    }

    try {
      final response = await _model
          .generateContent([Content.text(prompt)])
          .timeout(const Duration(seconds: 30));

      final text = response.text?.trim() ?? '';
      if (text.isEmpty) {
        throw const AiException('Gemini yanıtı boş döndü veya içerik güvenlik filtresine takıldı.');
      }
      return text;
    } on SocketException catch (e) {
      throw AiException.network(e.message);
    } on TimeoutException {
      throw const AiException('Gemini isteği zaman aşımına uğradı (30 saniye). Lütfen internet bağlantınızı kontrol edin.');
    } on GenerativeAIException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('api_key') || msg.contains('invalid') || msg.contains('unauthorized')) {
        throw AiException.invalidApiKey();
      } else if (msg.contains('quota') || msg.contains('resource_exhausted') || msg.contains('429')) {
        throw AiException.rateLimited();
      }
      throw AiException('Gemini servisi hatası: ${e.message}');
    } on AiException {
      rethrow;
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('SocketException') || errStr.contains('Failed host lookup')) {
        throw AiException.network();
      }
      throw AiException('Gemini işlemi sırasında beklenmeyen bir hata oluştu: $e');
    }
  }

  @override
  Future<String> generateSummary(String text) async {
    final prompt = "Aşağıdaki metni çok kısa ve net şekilde özetle:\n\n$text";
    return await _safeGenerate(prompt);
  }

  @override
  Future<List<String>> suggestTags(String text) async {
    final prompt = "Aşağıdaki metin için sadece virgülle ayrılmış tek kelimelik etiketler öner. Markdown veya başka açıklama kullanma:\n\n$text";
    final raw = await _safeGenerate(prompt);
    return raw
        .split(',')
        .map((e) => e.trim().replaceAll('#', ''))
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  Future<String> customPrompt(String prompt, String content) async {
    return await _safeGenerate("$prompt\n\n$content");
  }
}
