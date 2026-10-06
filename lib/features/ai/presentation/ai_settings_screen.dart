import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/ai_provider.dart';
import '../models/ai_provider_type.dart';
import '../models/ai_config.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key});

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  AiProviderType _selectedType = AiProviderType.none;
  final TextEditingController _apiKeyController = TextEditingController();
  final TextEditingController _baseUrlController = TextEditingController();
  final TextEditingController _modelController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AiProvider>();
      setState(() {
        _selectedType = provider.config.providerType;
        _apiKeyController.text = provider.config.apiKey ?? '';
        _baseUrlController.text = provider.config.baseUrl ?? '';
        _modelController.text = provider.config.modelName ?? '';
      });
    });
  }

  void _save() async {
    final provider = context.read<AiProvider>();
    await provider.saveConfig(AiConfig(
      providerType: _selectedType,
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      modelName: _modelController.text.trim(),
    ));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('AI ayarları kaydedildi'), backgroundColor: Colors.green),
      );
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Yapay Zeka (AI) Ayarları')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('GümüşNot yapay zeka entegrasyonu tamamen "Kendi Anahtarını Getir" (BYOK) mantığıyla çalışır. İstediğiniz API anahtarını girerek modeli seçebilirsiniz.'),
            const SizedBox(height: 24),
            DropdownButtonFormField<AiProviderType>(
              initialValue: _selectedType,
              decoration: const InputDecoration(labelText: 'AI Sağlayıcısı (Provider)', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: AiProviderType.none, child: Text('Kapalı')),
                DropdownMenuItem(value: AiProviderType.gemini, child: Text('Google Gemini')),
                DropdownMenuItem(value: AiProviderType.openAiCompatible, child: Text('OpenAI / DeepSeek / Özel Model')),
              ],
              onChanged: (val) {
                if (val != null) setState(() => _selectedType = val);
              },
            ),
            const SizedBox(height: 16),
            if (_selectedType != AiProviderType.none) ...[
              TextField(
                controller: _apiKeyController,
                decoration: InputDecoration(
                  labelText: 'API Anahtarı (API Key)',
                  border: const OutlineInputBorder(),
                  helperText: _selectedType == AiProviderType.gemini 
                      ? 'Google AI Studio üzerinden ücretsiz alabilirsiniz.'
                      : 'OpenAI, DeepSeek veya diğer servislerin API anahtarı',
                ),
                obscureText: true,
              ),
              const SizedBox(height: 16),
            ],
            if (_selectedType == AiProviderType.openAiCompatible) ...[
              TextField(
                controller: _baseUrlController,
                decoration: const InputDecoration(
                  labelText: 'Base URL (Opsiyonel)',
                  border: OutlineInputBorder(),
                  hintText: 'Örn: https://api.deepseek.com/v1',
                  helperText: 'DeepSeek için https://api.deepseek.com/v1 yazın. Boş bırakılırsa standart OpenAI kullanılır.',
                ),
              ),
              const SizedBox(height: 16),
            ],
            if (_selectedType != AiProviderType.none) ...[
              TextField(
                controller: _modelController,
                decoration: InputDecoration(
                  labelText: 'Model Adı (Opsiyonel)',
                  border: const OutlineInputBorder(),
                  hintText: _selectedType == AiProviderType.gemini ? 'gemini-1.5-flash' : 'gpt-4o-mini',
                  helperText: 'Boş bırakılırsa varsayılan hızlı model kullanılır.',
                ),
              ),
              const SizedBox(height: 32),
            ],
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _save,
                child: const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
