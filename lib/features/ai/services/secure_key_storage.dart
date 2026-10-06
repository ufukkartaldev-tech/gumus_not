import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/ai_provider_type.dart';
import '../models/ai_config.dart';

class SecureKeyStorage {
  static const _storage = FlutterSecureStorage();
  
  static const _keyProviderType = 'ai_provider_type';
  static const _keyApiKey = 'ai_api_key';
  static const _keyBaseUrl = 'ai_base_url';
  static const _keyModelName = 'ai_model_name';

  Future<void> saveConfig(AiConfig config) async {
    await _storage.write(key: _keyProviderType, value: config.providerType.name);
    
    if (config.apiKey != null && config.apiKey!.isNotEmpty) {
      await _storage.write(key: _keyApiKey, value: config.apiKey);
    } else {
      await _storage.delete(key: _keyApiKey);
    }
    
    if (config.baseUrl != null && config.baseUrl!.isNotEmpty) {
      await _storage.write(key: _keyBaseUrl, value: config.baseUrl);
    } else {
      await _storage.delete(key: _keyBaseUrl);
    }

    if (config.modelName != null && config.modelName!.isNotEmpty) {
      await _storage.write(key: _keyModelName, value: config.modelName);
    } else {
      await _storage.delete(key: _keyModelName);
    }
  }

  Future<AiConfig> loadConfig() async {
    final typeStr = await _storage.read(key: _keyProviderType) ?? AiProviderType.none.name;
    final apiKey = await _storage.read(key: _keyApiKey);
    final baseUrl = await _storage.read(key: _keyBaseUrl);
    final modelName = await _storage.read(key: _keyModelName);

    final type = AiProviderType.values.firstWhere(
      (e) => e.name == typeStr, 
      orElse: () => AiProviderType.none
    );

    return AiConfig(
      providerType: type,
      apiKey: apiKey,
      baseUrl: baseUrl,
      modelName: modelName,
    );
  }
}
