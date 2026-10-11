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
  bool _isTesting = false;

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

  @override
  void dispose() {
    _apiKeyController.dispose();
    _baseUrlController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  AiConfig _buildCurrentConfig() {
    return AiConfig(
      providerType: _selectedType,
      apiKey: _apiKeyController.text.trim(),
      baseUrl: _baseUrlController.text.trim(),
      modelName: _modelController.text.trim(),
    );
  }

  Future<void> _testConnection() async {
    final apiKey = _apiKeyController.text.trim();
    if (_selectedType == AiProviderType.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen önce bir AI sağlayıcısı seçin.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen test etmeden önce bir API anahtarı girin.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isTesting = true);

    final provider = context.read<AiProvider>();
    final error = await provider.testConnection(_buildCurrentConfig());

    if (!mounted) return;
    setState(() => _isTesting = false);

    if (error == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bağlantı başarılı! AI servisi sorunsuz çalışıyor. ✅'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bağlantı Hatası: $error'),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  void _save() async {
    final apiKey = _apiKeyController.text.trim();
    if (_selectedType != AiProviderType.none && apiKey.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Lütfen seçili servis için geçerli bir API anahtarı girin veya servisi "Kapalı" yapın.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final provider = context.read<AiProvider>();
    await provider.saveConfig(_buildCurrentConfig());

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
            const Text(
              'GümüşNot yapay zeka entegrasyonu tamamen "Kendi Anahtarını Getir" (BYOK) mantığıyla çalışır. İstediğiniz API anahtarını girerek modeli seçebilirsiniz.',
            ),
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
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton.icon(
                  onPressed: _isTesting ? null : _testConnection,
                  icon: _isTesting
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bolt_rounded),
                  label: Text(_isTesting ? 'Test Ediliyor...' : 'Bağlantıyı Test Et'),
                ),
              ),
              const SizedBox(height: 16),
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
