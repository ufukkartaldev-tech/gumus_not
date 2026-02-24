import 'package:flutter/material.dart';
import '../services/backup_share_service.dart';
import '../services/database_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final BackupShareService _backupService = BackupShareService();
  bool _isLoading = false;
  int _totalNotes = 0;

  @override
  void initState() {
    super.initState();
    _loadNoteCount();
  }

  Future<void> _loadNoteCount() async {
    try {
      final notes = await DatabaseService.getAllNotes();
      setState(() {
        _totalNotes = notes.length;
      });
    } catch (e) {
      print("Not sayısı yüklenemedi: $e");
    }
  }

  Future<void> _exportBackup() async {
    setState(() => _isLoading = true);
    
    try {
      final success = await _backupService.exportAndShareBackup();
      if (success) {
        _showSuccessMessage("Yedekleme dosyası hazırlandı ve paylaşım ekranı açıldı.");
      } else {
        _showErrorMessage("Yedeklenecek not bulunamadı veya hata oluştu.");
      }
    } catch (e) {
      _showErrorMessage("Yedekleme hatası: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _importBackup() async {
    // Onay dialogu göster
    final confirmed = await _showRestoreConfirmation();
    if (!confirmed) return;

    setState(() => _isLoading = true);
    
    try {
      final result = await _backupService.importAndRestoreBackup();
      if (result['success'] == true) {
        await _loadNoteCount();
        _showSuccessMessage(result['message']);
      } else {
        _showErrorMessage(result['message'] ?? "Bilinmeyen bir hata oluştu.");
      }
    } catch (e) {
      _showErrorMessage("Geri yükleme hatası: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<bool> _showRestoreConfirmation() async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yedekten Geri Yükle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Yedekten geri yükleme işlemi, bu cihazdaki notlara ekleme yapacaktır.'),
            const SizedBox(height: 8),
            const Text('Devam etmek istiyor musunuz?', style: TextStyle(color: Colors.orange)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Evet, Geri Yükle'),
          ),
        ],
      ),
    ) ?? false;
  }

  void _showSuccessMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yedekleme & Senkronizasyon'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Durum Kartı
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.sd_storage,
                                color: Colors.blue,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Yerel Yedekleme',
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    Text(
                                      'Cihazdaki Toplam Not: $_totalNotes',
                                      style: Theme.of(context).textTheme.bodyMedium,
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _exportBackup,
                                  icon: const Icon(Icons.share),
                                  label: const Text('Dışa Aktar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.green,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _importBackup,
                                  icon: const Icon(Icons.file_open),
                                  label: const Text('İçe Aktar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.orange,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Bilgi Kartı
                  Card(
                    color: Theme.of(context).colorScheme.surfaceVariant,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bilgi',
                            style: Theme.of(context).textTheme.titleMedium,
                          ),
                          const SizedBox(height: 8),
                          const Text('• Tüm notlarınızı şifreli bir .gnb dosyası olarak dışa aktarabilirsiniz.'),
                          const Text('• Oluşturulan yedek dosyasını WhatsApp, Telegram veya e-posta yoluyla kendinize göndererek güvenle saklayabilirsiniz.'),
                          const Text('• İçe aktarırken daha önceden kaydettiğiniz yedek dosyasını seçmeniz yeterlidir.'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
