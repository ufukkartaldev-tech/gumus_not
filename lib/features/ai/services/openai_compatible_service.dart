import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'iai_service.dart';
import '../models/ai_config.dart';
import '../models/ai_exception.dart';

class OpenAiCompatibleService implements IAiService {
  final String _apiKey;
  final String _baseUrl;
  final String _modelName;
  final http.Client _client;

  OpenAiCompatibleService(AiConfig config, {http.Client? client})
      : _apiKey = config.apiKey?.trim() ?? '',
        _baseUrl = config.baseUrl?.isNotEmpty == true
            ? config.baseUrl!.trim().replaceAll(RegExp(r'/+$'), '')
            : 'https://api.openai.com/v1',
        _modelName = config.modelName?.isNotEmpty == true ? config.modelName!.trim() : 'gpt-4o-mini',
        _client = client ?? http.Client();

  Future<String> _makeRequest(String prompt) async {
    if (_apiKey.isEmpty) {
      throw AiException.missingApiKey();
    }

    final url = Uri.parse('$_baseUrl/chat/completions');

    try {
      final response = await _client.post(
        url,
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $_apiKey',
        },
        body: jsonEncode({
          'model': _modelName,
          'messages': [
            {'role': 'user', 'content': prompt}
          ],
          'max_tokens': 250,
        }),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        String decodedBody;
        try {
          decodedBody = utf8.decode(response.bodyBytes);
        } catch (_) {
          decodedBody = response.body;
        }
        final Map<String, dynamic> data = jsonDecode(decodedBody);
        final choices = data['choices'] as List?;
        if (choices == null || choices.isEmpty) {
          throw const AiException('AI servisinden geçerli bir yanıt içeriği alınamadı.');
        }
        final content = choices[0]['message']?['content'] as String?;
        if (content == null || content.trim().isEmpty) {
          throw const AiException('AI servisi boş yanıt döndürdü.');
        }
        return content.trim();
      } else if (response.statusCode == 401 || response.statusCode == 403) {
        throw AiException.invalidApiKey(response.statusCode);
      } else if (response.statusCode == 429) {
        throw AiException.rateLimited(response.statusCode);
      } else if (response.statusCode >= 500) {
        throw AiException.server(response.statusCode);
      } else {
        String serverMessage = '';
        try {
          final errData = jsonDecode(utf8.decode(response.bodyBytes));
          serverMessage = errData['error']?['message'] ?? '';
        } catch (_) {}
        throw AiException.server(response.statusCode, serverMessage.isNotEmpty ? serverMessage : null);
      }
    } on SocketException catch (e) {
      throw AiException.network(e.message);
    } on TimeoutException {
      throw const AiException('İstek zaman aşımına uğradı (30 saniye). Lütfen ağ bağlantınızı kontrol edin.');
    } on FormatException {
      throw const AiException('Sunucudan geçersiz veri formatı alındı.');
    } on AiException {
      rethrow;
    } catch (e) {
      final errStr = e.toString();
      if (errStr.contains('SocketException') || errStr.contains('ClientException') || errStr.contains('Failed host lookup')) {
        throw AiException.network();
      }
      throw AiException('AI servisi ile iletişim kurulurken bir hata oluştu: $e');
    }
  }

  @override
  Future<String> generateSummary(String text) async {
    final prompt = "Aşağıdaki metni çok kısa ve net şekilde özetle:\n\n$text";
    return await _makeRequest(prompt);
  }

  @override
  Future<List<String>> suggestTags(String text) async {
    final prompt = "Aşağıdaki metin için sadece virgülle ayrılmış tek kelimelik etiketler öner. Markdown veya başka açıklama kullanma:\n\n$text";
    final raw = await _makeRequest(prompt);
    return raw
        .split(',')
        .map((e) => e.trim().replaceAll('#', ''))
        .where((e) => e.isNotEmpty)
        .toList();
  }

  @override
  Future<String> customPrompt(String prompt, String content) async {
    return await _makeRequest("$prompt\n\n$content");
  }
}
