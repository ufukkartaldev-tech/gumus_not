import 'ai_provider_type.dart';

class AiConfig {
  final AiProviderType providerType;
  final String? apiKey;
  final String? baseUrl; // Needed for DeepSeek/Custom models
  final String? modelName; // e.g. "deepseek-chat" or "gpt-4o"

  AiConfig({
    required this.providerType,
    this.apiKey,
    this.baseUrl,
    this.modelName,
  });
}
