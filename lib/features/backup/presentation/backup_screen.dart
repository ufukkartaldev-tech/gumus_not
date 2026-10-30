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

  bool _isWindows(BuildContext context) =>
      Theme.of(context).platform == TargetPlatform.windows;

  @override
  void initState() {
    super.initState();
    _loadNoteCount();
  }

  Future<void> _loadNoteCount() async {
    try {
      final noteProvider = Provider.of<NoteProvider>(context, listen: false);
      await noteProvider.loadNotes();
      if (mounted) {
        setState(() {
          _totalNotes = noteProvider.notes.length;
        });
      }
    } catch (e) {
      debugPrint("Not sayısı yüklenemedi: $e");
    }
  }

  Future<void> _exportEncryptedBackup() async {
    final password = await _showPasswordCreationDialog(
      title: 'Şifreli Yedek Oluştur (.enc)',
      description:
          'Yedeğiniz AES-256-GCM ve PBKDF2 ile güvenli şekilde şifrelenecektir. '
          'Parolanızı unutursanız yedeğinizdeki verilere bir daha asla erişilemez.',
      confirmLabel: 'Şifrele ve Kaydet',
    );
    if (password == null || password.isEmpty) return;
    if (!mounted) return;

    setState(() => _isLoading = true);
    try {
      final result = await _backupService.exportEncryptedBackup(
        context,
        password: password,
      );
      if (result['success'] == true) {
        _showSuccessMessage(result['message'] ?? 'Şifreli yedek oluşturuldu.');
      } else if (result['cancelled'] != true) {
        _showErrorMessage(result['message'] ?? 'Yedekleme başarısız oldu.');
      }
    } catch (e) {
      _showErrorMessage('Yedekleme hatası: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importEncryptedBackup() async {
    final password = await _showPasswordDialog(
      title: 'Şifreli Yedeği Aç (.enc)',
      description:
          'Seçeceğiniz şifreli yedeği açmak için yedeği oluştururken belirlediğiniz parolayı girin.',
      confirmLabel: 'Dosya Seç ve Geri Yükle',
    );
    if (password == null || password.isEmpty) return;

    final replaceExisting = await _showRestoreModeDialog();
    if (replaceExisting == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final result = await _backupService.importEncryptedBackup(
        context,
        password: password,
        replaceExisting: replaceExisting,
      );
      if (result['success'] == true) {
        await _loadNoteCount();
        _showSuccessMessage(result['message'] ?? 'Geri yükleme tamamlandı.');
      } else if (result['cancelled'] != true) {
        _showErrorMessage(result['message'] ?? 'Geri yükleme başarısız oldu.');
      }
    } catch (e) {
      _showErrorMessage('Geri yükleme hatası: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _exportZipBackup() async {
    final confirmed = await _showZipWarningDialog();
    if (!confirmed || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final result = await _backupService.exportZipArchive(context);
      if (result['success'] == true) {
        _showSuccessMessage(result['message'] ?? 'Taşınabilir arşiv oluşturuldu.');
      } else if (result['cancelled'] != true) {
        _showErrorMessage(result['message'] ?? 'Dışa aktarma başarısız oldu.');
      }
    } catch (e) {
      _showErrorMessage('Dışa aktarma hatası: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _importZipBackup() async {
    final replaceExisting = await _showRestoreModeDialog();
    if (replaceExisting == null || !mounted) return;

    setState(() => _isLoading = true);
    try {
      final result = await _backupService.importZipArchive(
        context,
        replaceExisting: replaceExisting,
      );
      if (result['success'] == true) {
        await _loadNoteCount();
        _showSuccessMessage(result['message'] ?? 'ZIP arşivi geri yüklendi.');
      } else if (result['cancelled'] != true) {
        _showErrorMessage(result['message'] ?? 'İçe aktarma başarısız oldu.');
      }
    } catch (e) {
      _showErrorMessage('İçe aktarma hatası: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

  Future<String?> _showPasswordCreationDialog({
    required String title,
    required String description,
    required String confirmLabel,
  }) {
    final passController = TextEditingController();
    final confirmController = TextEditingController();
    String? errorText;

    return showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(description, style: const TextStyle(fontSize: 13)),
              const SizedBox(height: 16),
              TextField(
                controller: passController,
                obscureText: true,
                autofocus: true,
                decoration: const InputDecoration(
                  labelText: 'Yedekleme Parolası (En az 6 karakter)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Parolayı Tekrar Girin',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
              ),
              if (errorText != null) ...[
                const SizedBox(height: 8),
                Text(errorText!, style: const TextStyle(color: Colors.red, fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('İptal'),
            ),
            ElevatedButton(
              onPressed: () {
                final p1 = passController.text;
                final p2 = confirmController.text;
                if (p1.length < 6) {
                  setDialogState(() => errorText = 'Parola en az 6 karakter olmalıdır.');
                  return;
                }
                if (p1 != p2) {
                  setDialogState(() => errorText = 'Girdiğiniz parolalar eşleşmiyor.');
                  return;
                }
                Navigator.of(dialogContext).pop(p1);
              },
              child: Text(confirmLabel),
            ),
          ],
        ),
      ),
    );
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(description, style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              obscureText: true,
              autofocus: true,
              decoration: const InputDecoration(
                labelText: 'Yedekleme Parolası',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.lock_outline),
              ),
              onSubmitted: (val) => Navigator.of(dialogContext).pop(val),
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

  Future<bool?> _showRestoreModeDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('Geri Yükleme Seçeneği'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Yedekteki notları mevcut notlarınızla nasıl birleştirmek istersiniz?',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 16),
            Text(
              '• Mevcut Notları Koru ve Birleştir (Önerilen): Mevcut notlarınız silinmez. Yedekteki aynı isimli farklı notlar yedek kopyası olarak eklenir.',
              style: TextStyle(fontSize: 12, color: Colors.teal),
            ),
            SizedBox(height: 8),
            Text(
              '• Temiz Kurulum (Tam Değiştir): Mevcut notlar silinerek çalışma alanı yedekle birebir eşitlenir.',
              style: TextStyle(fontSize: 12, color: Colors.orange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('İptal'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('Temiz Kurulum'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white),
            child: const Text('Koru ve Birleştir'),
          ),
        ],
      ),
    );
  }

  Future<bool> _showZipWarningDialog() async {
    return await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.amber, size: 28),
            SizedBox(width: 8),
            Text('Şifresiz Arşiv Uyarısı'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Oluşturulacak ZIP arşivi şifresiz düz metin Markdown dosyaları içerir.',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'Bu dosya parola ile korunmaz ve herhangi bir metin editörü veya dosya yöneticisiyle herkes tarafından doğrudan okunabilir.',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 8),
            Text(
              'Dışa aktarmaya devam etmek istiyor musunuz?',
              style: TextStyle(fontSize: 13, color: Colors.deepOrange),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('İptal'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade800, foregroundColor: Colors.white),
            child: const Text('Anladım, ZIP Oluştur'),
          ),
        ],
      ),
    ) ?? false;
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
        title: const Text('Yedekleme ve Geri Yükleme'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: busy
          ? const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('İşlem yapılıyor, lütfen bekleyin...'),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Durum Kartı
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Icon(
                            Icons.folder_special_rounded,
                            color: Theme.of(context).colorScheme.primary,
                            size: 36,
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Yerel Not Koleksiyonu',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.bold,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Cihazdaki Toplam Not: $_totalNotes',
                                  style: Theme.of(context).textTheme.bodyMedium,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // 1. Şifreli Yedekleme Kartı (.enc) - Varsayılan ve Önerilen
                  Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.teal.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.shield_outlined, color: Colors.teal, size: 26),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Şifreli Yerel Yedek (.enc)',
                                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                                fontWeight: FontWeight.bold,
                                              ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: Colors.green.withValues(alpha: 0.2),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: const Text(
                                            'Önerilen',
                                            style: TextStyle(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'AES-256-GCM ve PBKDF2 ile tam şifreli yerel dosya',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          const Text(
                            'Tüm notlarınız, klasörleriniz ve şablonlarınız parolanızla şifrelenir. '
                            'Dosya güvenle USB bellekte, harici diskte veya bulut klasöründe saklanabilir.',
                            style: TextStyle(fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _exportEncryptedBackup,
                                  icon: const Icon(Icons.lock_outline),
                                  label: const Text('Şifreli Yedek Al'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.teal,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _importEncryptedBackup,
                                  icon: const Icon(Icons.lock_open_outlined),
                                  label: const Text('Yedekten Yükle'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
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

                  // 2. Taşınabilir Arşiv Kartı (.zip)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.amber.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: const Icon(Icons.folder_zip_outlined, color: Colors.amber, size: 26),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Taşınabilir Not Arşivi (.zip)',
                                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 2),
                                    const Text(
                                      'Standart Markdown ve şablonlar (Şifresiz)',
                                      style: TextStyle(fontSize: 12, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.amber.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.info_outline, color: Colors.amber, size: 20),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'DİKKAT: ZIP dosyası şifresiz düz metin Markdown içerir. Notlarınız herhangi bir metin editörüyle okunabilir.',
                                    style: TextStyle(fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton.icon(
                                  onPressed: _exportZipBackup,
                                  icon: const Icon(Icons.file_download_outlined),
                                  label: const Text('ZIP Dışa Aktar'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.amber.shade800,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: _importZipBackup,
                                  icon: const Icon(Icons.file_upload_outlined),
                                  label: const Text('ZIP İçe Aktar'),
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3. Google Drive Kartı - Sadece Windows Dışındaki Platformlarda Göster
                  if (!_isWindows(context)) ...[
                    const SizedBox(height: 16),
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
                                  size: 28,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Google Drive Yedekleme',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.bold,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Notlarınız parolanızla şifrelenip Drive\'ın gizli uygulama klasörüne yüklenir.',
                              style: TextStyle(fontSize: 13),
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
                  ],

                  const SizedBox(height: 16),

                  // Güvenlik & Kurtarma Bilgi Kartı
                  Card(
                    color: Theme.of(context).colorScheme.surfaceContainerHighest,
                    child: const Padding(
                      padding: EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.verified_user_outlined, size: 20),
                              SizedBox(width: 8),
                              Text(
                                'Güvenlik ve Geri Yükleme Güvencesi',
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          SizedBox(height: 8),
                          Text(
                            '• Otomatik Güvenlik Yedeği: Geri yükleme başlamadan önce mevcut çalışma alanınızın otomatik anlık görüntüsü alınır. Herhangi bir hata veya bozuk dosya durumunda mevcut notlarınız anında geri yüklenir (rollback).',
                            style: TextStyle(fontSize: 12),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '• Çakışma Koruması: "Koru ve Birleştir" modu mevcut dosyalarınızı asla sessizce ezmez; aynı isimli notlar "(Yedekten)" kopyası olarak eklenir.',
                            style: TextStyle(fontSize: 12),
                          ),
                          SizedBox(height: 6),
                          Text(
                            '• Dizin Yolu Güvenliği: Yedek dosyaları path traversal ve dosya sistemi enjeksiyonlarına karşı sıkı doğrulamadan geçirilir.',
                            style: TextStyle(fontSize: 12),
                          ),
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
