import 'dart:convert';
import 'package:http/http.dart' as http;
import 'iai_service.dart';
import '../models/ai_config.dart';

class OpenAiCompatibleService implements IAiService {
  final String _apiKey;
  final String _baseUrl;
  final String _modelName;

  OpenAiCompatibleService(AiConfig config)
      : _apiKey = config.apiKey ?? '',
        _baseUrl = config.baseUrl?.isNotEmpty == true ? config.baseUrl!.replaceAll(RegExp(r'/$'), '') : 'https://api.openai.com/v1',
        _modelName = config.modelName?.isNotEmpty == true ? config.modelName! : 'gpt-4o-mini';

  Future<String> _makeRequest(String prompt) async {
    final url = Uri.parse('$_baseUrl/chat/completions');
    
    final response = await http.post(
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
        'max_tokens': 150, // Maliyet tasarrufu: Gevezeliği önler
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes));
      return data['choices'][0]['message']['content'];
    } else {
      throw Exception('API Hatası: ${response.statusCode} - ${response.body}');
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
    return raw.split(',').map((e) => e.trim().replaceAll('#', '')).where((e) => e.isNotEmpty).toList();
  }

  @override
  Future<String> customPrompt(String prompt, String content) async {
    return await _makeRequest("$prompt\n\n$content");
  }
}
