import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connected_notebook/core/theme/theme_provider.dart';
import 'package:connected_notebook/core/theme/app_theme.dart';
import 'package:connected_notebook/features/settings/presentation/about_screen.dart';
import 'package:connected_notebook/features/home_widget/presentation/widget_screen.dart';
import 'package:connected_notebook/core/utils/shortcut_manager.dart';

import 'package:connected_notebook/features/ai/presentation/ai_settings_screen.dart';
import 'package:connected_notebook/features/settings/screens/theme_selection_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  void initState() {
    super.initState();
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

