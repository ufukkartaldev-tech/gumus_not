import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/note_provider.dart';
import '../providers/theme_provider.dart';
import '../themes/app_theme.dart';
import '../services/encryption_service.dart';
import 'about_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({Key? key}) : super(key: key);

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isEncryptionEnabled = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;

  @override
  void initState() {
    super.initState();
    _checkEncryptionStatus();
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _checkEncryptionStatus() async {
    final isEnabled = EncryptionService.isInitialized();
    setState(() {
      _isEncryptionEnabled = isEnabled;
    });
  }

  Future<void> _enableEncryption() async {
    if (_passwordController.text.isEmpty) {
      _showError('Şifre boş olamaz');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Şifreler eşleşmiyor');
      return;
    }

    if (_passwordController.text.length < 8) {
      _showError('Şifre en az 8 karakter olmalıdır');
      return;
    }

    try {
      await EncryptionService.initialize(_passwordController.text);
      setState(() {
        _isEncryptionEnabled = true;
      });
      
      _passwordController.clear();
      _confirmPasswordController.clear();
      
      _showSuccess('Şifreleme başarıyla etkinleştirildi');
    } catch (e) {
      _showError('Şifreleme etkinleştirilemedi: $e');
    }
  }

  void _disableEncryption() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şifrelemeyi Devre Dışı Bırak'),
        content: const Text(
          'Şifrelemeyi devre dışı bırakmak, tüm şifreli notların şifresini kaldıracaktır. '
          'Bu işlem geri alınamaz. Devam etmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () {
              setState(() {
                _isEncryptionEnabled = false;
              });
              Navigator.of(context).pop();
              _showSuccess('Şifreleme devre dışı bırakıldı');
            },
            child: const Text('Devre Dışı Bırak', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
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

  Future<void> _exportNotes() async {
    try {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      await noteProvider.loadNotes();
      
      _showSuccess('Notlar başarıyla dışa aktarıldı');
    } catch (e) {
      _showError('Dışa aktarma başarısız: $e');
    }
  }

  Future<void> _clearAllData() async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tüm Verileri Temizle'),
        content: const Text(
          'Bu işlem tüm notlarınızı ve bağlantılarınızı kalıcı olarak silecektir. '
          'Bu işlem geri alınamaz. Devam etmek istediğinizden emin misiniz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              try {
                final noteProvider = Provider.of<NoteProvider>(context, listen: false);
                for (final note in noteProvider.notes) {
                  if (note.id != null) {
                    await noteProvider.deleteNote(note.id!);
                  }
                }
                _showSuccess('Tüm veriler temizlendi');
              } catch (e) {
                _showError('Veriler temizlenemedi: $e');
              }
            },
            child: const Text('Temizle', style: TextStyle(color: Colors.red)),
          ),
        ],
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
          _buildThemeSection(),
          const SizedBox(height: 24),
          _buildEncryptionSection(),
          const SizedBox(height: 24),
          _buildDataManagementSection(),
          const SizedBox(height: 24),
          _buildAboutSection(),
        ],
      ),
    );
  }

  Widget _buildThemeSection() {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Row(
                  children: [
                    Icon(Icons.palette, size: 24),
                    SizedBox(width: 8),
                    Text(
                      'Görünüm',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                const Text('Tema Modu', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(value: ThemeMode.light, icon: Icon(Icons.light_mode), label: Text('Açık')),
                    ButtonSegment(value: ThemeMode.dark, icon: Icon(Icons.dark_mode), label: Text('Koyu')),
                    ButtonSegment(value: ThemeMode.system, icon: Icon(Icons.brightness_auto), label: Text('Sistem')),
                  ],
                  selected: {themeProvider.themeMode},
                  onSelectionChanged: (Set<ThemeMode> newSelection) {
                    themeProvider.setThemeMode(newSelection.first);
                  },
                ),
                const SizedBox(height: 16),
                const Text('Tema Rengi', style: TextStyle(fontWeight: FontWeight.w600)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: AppThemeColor.values.map((color) {
                    final isSelected = themeProvider.selectedColor == color;
                    return InkWell(
                      onTap: () => themeProvider.setThemeColor(color),
                      borderRadius: BorderRadius.circular(20),
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: color.color,
                          shape: BoxShape.circle,
                          border: isSelected 
                              ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3)
                              : null,
                          boxShadow: [
                            BoxShadow(
                              color: color.color.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: isSelected 
                            ? const Icon(Icons.check, color: Colors.white, size: 20)
                            : null,
                      ),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildEncryptionSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.lock, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Şifreleme',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                Switch(
                  value: _isEncryptionEnabled,
                  onChanged: (value) {
                    if (value) {
                      _showEncryptionDialog();
                    } else {
                      _disableEncryption();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              _isEncryptionEnabled
                  ? 'Şifreleme etkin. Notlarınız AES-256 ile korunuyor.'
                  : 'Şifreleme devre dışı. Notlarınız şifrelenmiyor.',
              style: TextStyle(
                color: _isEncryptionEnabled ? Colors.green : Colors.orange,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDataManagementSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.storage, size: 24),
                SizedBox(width: 8),
                Text(
                  'Veri Yönetimi',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.download),
              title: const Text('Notları Dışa Aktar'),
              subtitle: const Text('Tüm notları JSON formatında dışa aktar'),
              onTap: _exportNotes,
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.delete_forever, color: Colors.red),
              title: const Text('Tüm Verileri Temizle'),
              subtitle: const Text('Tüm notları ve bağlantıları kalıcı olarak sil'),
              onTap: _clearAllData,
            ),
          ],
        ),
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

  void _showEncryptionDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Şifrelemeyi Etkinleştir'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Notlarınızı şifrelemek için bir anahtar şifre oluşturun. '
              'Bu şifreyi unutursanız verilerinize erişemezsiniz!',
              style: TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              obscureText: !_showPassword,
              decoration: InputDecoration(
                labelText: 'Şifre',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _showPassword = !_showPassword;
                    });
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _confirmPasswordController,
              obscureText: !_showConfirmPassword,
              decoration: InputDecoration(
                labelText: 'Şifre Tekrarı',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: Icon(_showConfirmPassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: () {
                    setState(() {
                      _showConfirmPassword = !_showConfirmPassword;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _enableEncryption();
            },
            child: const Text('Etkinleştir'),
          ),
        ],
      ),
    );
  }
}
