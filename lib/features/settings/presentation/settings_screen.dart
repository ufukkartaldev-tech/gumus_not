import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connected_notebook/core/theme/theme_provider.dart';
import 'package:connected_notebook/core/theme/app_theme.dart';
import 'package:connected_notebook/features/settings/presentation/about_screen.dart';
import 'package:connected_notebook/features/home_widget/presentation/widget_screen.dart';
import 'package:connected_notebook/core/utils/shortcut_manager.dart';

import 'package:connected_notebook/features/ai/presentation/ai_settings_screen.dart';
import 'package:connected_notebook/features/settings/screens/theme_selection_screen.dart';
import 'package:connected_notebook/features/security/services/biometric_service.dart';
import 'package:connected_notebook/core/security/note_encryption_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final BiometricService _biometricService = BiometricService();
  final NoteEncryptionService _encryptionService = NoteEncryptionService();
  bool _isAppLockEnabled = false;
  bool _isLoadingLockSetting = true;
  bool _hasVaultEnvelope = false;

  @override
  void initState() {
    super.initState();
    _loadAppLockSetting();
  }

  Future<void> _loadAppLockSetting() async {
    final enabled = await _biometricService.isAppLockEnabled();
    final hasEnvelope = await _encryptionService.hasEnvelope();
    if (mounted) {
      setState(() {
        _isAppLockEnabled = enabled;
        _hasVaultEnvelope = hasEnvelope;
        _isLoadingLockSetting = false;
      });
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ayarlar'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16.0),
        children: [
          _buildSecuritySection(),
          const SizedBox(height: 24),
          _buildAiSection(),
          const SizedBox(height: 24),
          _buildDeveloperSection(),
          const SizedBox(height: 24),
          _buildThemeSection(),
          const SizedBox(height: 24),
          _buildWidgetSection(),
          const SizedBox(height: 24),
          _buildAboutSection(),
        ],
      ),
    );
  }

  Widget _buildSecuritySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.security, size: 24),
                SizedBox(width: 8),
                Text(
                  'Güvenlik ve Gizlilik',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Uygulama Kilidi',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        'Uygulama açılışında parmak izi veya cihaz şifresi iste',
                        style: TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                _isLoadingLockSetting
                    ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Switch(
                        value: _isAppLockEnabled,
                        onChanged: (val) async {
                          if (val) {
                            // Açmak isterse önce bir kere kimlik doğrulasın
                            final authenticated = await _biometricService.authenticate();
                            if (!authenticated) {
                              _showError('Kimlik doğrulanamadığı için kilit etkinleştirilemedi');
                              return;
                            }
                          }
                          await _biometricService.setAppLockEnabled(val);
                          setState(() {
                            _isAppLockEnabled = val;
                          });
                          _showSuccess(
                            val
                                ? 'Uygulama kilidi etkinleştirildi'
                                : 'Uygulama kilidi kapatıldı',
                          );
                        },
                      ),
              ],
            ),
            const Divider(height: 24),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                _hasVaultEnvelope ? Icons.verified_user : Icons.key_outlined,
                color: _hasVaultEnvelope ? Colors.green : null,
              ),
              title: const Text(
                'Kasa Parolası (Envelope Encryption)',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _hasVaultEnvelope
                    ? 'Etkin — .vault_key.json ile cihazlar arası kurtarılabilir'
                    : 'Şifreli notları başka cihazlarda açabilmek için parola belirleyin',
                style: const TextStyle(fontSize: 12),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: _showVaultPasswordDialog,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showVaultPasswordDialog() async {
    final hasEnvelope = await _encryptionService.hasEnvelope();
    if (!mounted) return;

    final currentPassController = TextEditingController();
    final newPassController = TextEditingController();
    final confirmPassController = TextEditingController();
    String? errorText;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(
            hasEnvelope ? 'Kasa Parolasını Güncelle / Doğrula' : 'Kasa Parolası Belirle',
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                hasEnvelope
                    ? 'Mevcut parolanızı girerek kasayı bu cihazda açabilir veya yeni parola belirleyebilirsiniz.'
                    : 'Şifreli notların anahtarını (DEK) PBKDF2-HMAC-SHA256 ve AES-256-GCM ile .vault_key.json dosyasına sarmalar.',
                style: const TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 12),
              if (hasEnvelope) ...[
                TextField(
                  controller: currentPassController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Mevcut Kasa Parolası',
                  ),
                ),
                const SizedBox(height: 8),
              ],
              TextField(
                controller: newPassController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: hasEnvelope
                      ? 'Yeni Parola (sadece açmak için boş bırakın)'
                      : 'Yeni Kasa Parolası (en az 6 karakter)',
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: confirmPassController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Yeni Parola Tekrar',
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(
                  errorText!,
                  style: const TextStyle(color: Colors.red, fontSize: 12),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () async {
                final currentPass = currentPassController.text;
                final newPass = newPassController.text;
                final confirmPass = confirmPassController.text;

                try {
                  if (hasEnvelope && newPass.isEmpty) {
                    await _encryptionService.unlockWithMasterPassword(currentPass);
                    if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                    _showSuccess('Kasa anahtarı bu cihazda başarıyla açıldı');
                    return;
                  }

                  if (newPass.length < 6) {
                    setDialogState(
                      () => errorText = 'Yeni parola en az 6 karakter olmalıdır.',
                    );
                    return;
                  }
                  if (newPass != confirmPass) {
                    setDialogState(
                      () => errorText = 'Yeni parolalar eşleşmiyor.',
                    );
                    return;
                  }

                  if (hasEnvelope) {
                    await _encryptionService.changeMasterPassword(
                      currentPassword: currentPass,
                      newPassword: newPass,
                    );
                  } else {
                    await _encryptionService.setupMasterPassword(newPass);
                  }

                  if (dialogContext.mounted) Navigator.of(dialogContext).pop();
                  await _loadAppLockSetting();
                  _showSuccess('Kasa parolası (.vault_key.json) kaydedildi');
                } on InvalidVaultPasswordException {
                  setDialogState(() => errorText = 'Mevcut parola hatalı.');
                } catch (e) {
                  setDialogState(() => errorText = 'Hata: $e');
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAiSection() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.auto_awesome, color: Colors.deepPurple),
        title: const Text('Yapay Zeka (AI) Asistanı', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Gemini, DeepSeek, OpenAI yapılandırması'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AiSettingsScreen()),
          );
        },
      ),
    );
  }

  Widget _buildDeveloperSection() {
    return Consumer<AppShortcutManager>(
      builder: (context, shortcutManager, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.terminal, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Geliştirici Araçları',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Vim Tuş Bağlantıları', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text('Editörde h, j, k, l gibi Vim komutlarını etkinleştir', 
                               style: TextStyle(fontSize: 12, color: Colors.grey)),
                        ],
                      ),
                    ),
                    Switch(
                      value: shortcutManager.isVimModeEnabled,
                      onChanged: (val) {
                        shortcutManager.setVimMode(val);
                        _showSuccess(val ? 'Vim modu etkinleştirildi' : 'Vim modu devredışı');
                      },
                    ),
                  ],
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Komut Paleti Kısayolu', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(shortcutManager.customShortcuts['command_palette'] ?? 'ctrl+k'),
                  trailing: const Icon(Icons.edit, size: 20),
                  onTap: () {
                    // Kısayol düzenleme mantığı (basitçe prompt ile yapalım)
                    _editShortcut(shortcutManager, 'command_palette', 'Komut Paleti Kısayolu');
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Yeni Not Kısayolu', style: TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(shortcutManager.customShortcuts['new_note'] ?? 'ctrl+n'),
                  trailing: const Icon(Icons.edit, size: 20),
                  onTap: () {
                    _editShortcut(shortcutManager, 'new_note', 'Yeni Not Kısayolu');
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _editShortcut(AppShortcutManager manager, String action, String title) {
    final controller = TextEditingController(text: manager.customShortcuts[action] ?? '');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'örn. ctrl+k, cmd+shift+p',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              manager.updateShortcut(action, controller.text);
              Navigator.pop(ctx);
              _showSuccess('Kısayol güncellendi');
            },
            child: const Text('Kaydet'),
          ),
        ],
      ),
    );
  }


  Widget _buildThemeSection() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.color_lens_outlined, color: Colors.blue),
        title: const Text('Temalar ve Görünüm', style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: const Text('Dracula, Nord, karanlık/aydınlık mod'),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const ThemeSelectionScreen()),
          );
        },
      ),
    );
  }

  Widget _buildWidgetSection() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.widgets_outlined),
        title: const Text('Ana Ekran Widgetı'),
        subtitle: const Text('Widget görünümü, hızlı not ve senkronizasyon'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const WidgetScreen()),
          );
        },
      ),
    );
  }

  Widget _buildAboutSection() {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.info_outline),
        title: const Text('Hakkında ve Krediler'),
        subtitle: const Text('Uygulama bilgileri, sürüm ve teşekkürler'),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AboutScreen()),
          );
        },
      ),
    );
  }

}

