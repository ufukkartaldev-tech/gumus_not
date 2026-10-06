import 'package:google_generative_ai/google_generative_ai.dart';
import 'iai_service.dart';
import '../models/ai_config.dart';

class GeminiAiService implements IAiService {
  final GenerativeModel _model;

  GeminiAiService(AiConfig config)
      : _model = GenerativeModel(
          model: config.modelName?.isNotEmpty == true ? config.modelName! : 'gemini-1.5-flash',
          apiKey: config.apiKey ?? '',
        );

  @override
  Future<String> generateSummary(String text) async {
    final prompt = "Aşağıdaki metni çok kısa ve net şekilde özetle:\n\n$text";
    final response = await _model.generateContent([Content.text(prompt)]);
    return response.text ?? '';
  }

  @override
  Future<List<String>> suggestTags(String text) async {
    final prompt = "Aşağıdaki metin için sadece virgülle ayrılmış tek kelimelik etiketler öner. Markdown veya başka açıklama kullanma:\n\n$text";
    final response = await _model.generateContent([Content.text(prompt)]);
    final raw = response.text ?? '';
    return raw.split(',').map((e) => e.trim().replaceAll('#', '')).where((e) => e.isNotEmpty).toList();
  }

  @override
  Future<String> customPrompt(String prompt, String content) async {
    final fullPrompt = "$prompt\n\n$content";
    final response = await _model.generateContent([Content.text(fullPrompt)]);
    return response.text ?? '';
  }
}
