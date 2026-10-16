import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/features/backup/services/backup_share_service.dart';
import 'package:connected_notebook/features/backup/services/cloud_sync_service.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final BackupShareService _backupService = BackupShareService();
  final CloudSyncService _cloudSyncService = CloudSyncService();
  bool _isLoading = false;
  bool _cloudBusy = false;
  int _totalNotes = 0;

  @override
  void initState() {
    super.initState();
    _loadNoteCount();
  }

  Future<void> _loadNoteCount() async {
    try {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      await noteProvider.loadNotes();
      setState(() {
        _totalNotes = noteProvider.notes.length;
      });
    } catch (e) {
      print("Not sayısı yüklenemedi: $e");
    }
  }

  Future<void> _exportBackup() async {
    setState(() => _isLoading = true);

    try {
      final success = await _backupService.exportAndShareBackup(context);
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
      final result = await _backupService.importAndRestoreBackup(context);
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

  Future<void> _backupToDrive() async {
    final password = await _showPasswordDialog(
      title: 'Drive Yedeği Oluştur',
      description: 'Yedeğiniz bu parola ile AES-256 ile şifrelenecek. Parolayı '
          'kimseyle (Google dahil) paylaşmıyoruz; kaybederseniz yedeği açamazsınız.',
      confirmLabel: 'Şifrele ve Yükle',
    );
    if (password == null || password.isEmpty) return;

    setState(() => _cloudBusy = true);
    try {
      final result = await _cloudSyncService.backupToDrive(password);
      if (result['success'] == true) {
        _showSuccessMessage(result['message']);
      } else {
        _showErrorMessage(result['message'] ?? "Bilinmeyen bir hata oluştu.");
      }
    } catch (e) {
      _showErrorMessage("Drive yedekleme hatası: $e");
    } finally {
      if (mounted) setState(() => _cloudBusy = false);
    }
  }

  Future<void> _restoreFromDrive() async {
    final confirmed = await _showRestoreConfirmation(
      description: 'Google Drive yedeğinden geri yükleme, bu cihazdaki tüm '
          'not ve şablonları yedekteki içerikle değiştirecektir.',
    );
    if (!confirmed) return;

    final password = await _showPasswordDialog(
      title: 'Drive Yedeğini Aç',
      description: 'Yedeği oluştururken kullandığınız parolayı girin.',
      confirmLabel: 'İndir ve Geri Yükle',
    );
    if (password == null || password.isEmpty) return;

    setState(() => _cloudBusy = true);
    try {
      final result = await _cloudSyncService.restoreFromDrive(password);
      if (result['success'] == true) {
        await _loadNoteCount();
        _showSuccessMessage(result['message']);
      } else {
        _showErrorMessage(result['message'] ?? "Bilinmeyen bir hata oluştu.");
      }
    } catch (e) {
      _showErrorMessage("Drive geri yükleme hatası: $e");
    } finally {
      if (mounted) setState(() => _cloudBusy = false);
    }
  }

  Future<String?> _showPasswordDialog({
    required String title,
    required String description,
    required String confirmLabel,
  }) {
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Parola',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(controller.text),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
  }

  Future<bool> _showRestoreConfirmation({String? description}) async {
    return await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Yedekten Geri Yükle'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              description ??
                  'Yedekten geri yükleme işlemi, bu cihazdaki tüm not ve '
                  'şablonları yedekteki içerikle değiştirecektir. Yedekte '
                  'olmayan notlarınız silinecektir.',
            ),
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
    final busy = _isLoading || _cloudBusy;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Yedekleme & Senkronizasyon'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: busy
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

                  // Google Drive Kartı
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.cloud_sync_outlined,
                                color: Colors.deepPurple,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Google Drive Yedekleme',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Notlarınız parolanızla şifrelenip (AES-256) '
                            'Drive\'ın yalnızca uygulamanın görebildiği '
                            'gizli klasörüne yüklenir.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _backupToDrive,
                                  icon: const Icon(Icons.cloud_upload_outlined),
                                  label: const Text('Drive\'a Yedekle'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepPurple,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _restoreFromDrive,
                                  icon: const Icon(Icons.cloud_download_outlined),
                                  label: const Text('Drive\'dan Yükle'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.deepOrange,
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
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
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
                          const Text('• Yedek, tüm not ve şablonlarınızı içeren bir .zip dosyasıdır; içindeki dosyalar herhangi bir metin editörüyle açılabilen sade markdown\'dır.'),
                          const Text('• Oluşturulan yedek dosyasını WhatsApp, Telegram veya e-posta yoluyla kendinize göndererek güvenle saklayabilirsiniz.'),
                          const Text('• İçe aktarma, cihazdaki not ve şablonları yedekteki içerikle değiştirir; işlem öncesi onay sorulur.'),
                          const Text('• Drive yedeği parolanızla şifrelenir; parolayı kaybederseniz yedeğe erişilemez.'),
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
