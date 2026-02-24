import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../services/google_drive_service.dart';
import '../services/database_service.dart';
import '../models/note_model.dart';

class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  final GoogleDriveService _driveService = GoogleDriveService();
  final _secureStorage = const FlutterSecureStorage();
  bool _isLoading = false;
  bool _isAuthenticated = false;
  List<Map<String, dynamic>> _backupHistory = [];
  int _totalNotes = 0;

  @override
  void initState() {
    super.initState();
    _checkAuthenticationStatus();
    _loadBackupHistory();
    _loadNoteCount();
  }

  Future<void> _checkAuthenticationStatus() async {
    setState(() {
      _isAuthenticated = _driveService.isAuthenticated;
    });
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

  Future<void> _loadBackupHistory() async {
    if (!_isAuthenticated) return;
    
    try {
      final history = await _driveService.getBackupHistory();
      setState(() {
        _backupHistory = history;
      });
    } catch (e) {
      print("Yedekleme geçmişi yüklenemedi: $e");
    }
  }

  Future<void> _authenticate() async {
    setState(() => _isLoading = true);
    
    try {
      final success = await _driveService.authenticate();
      if (success) {
        setState(() {
          _isAuthenticated = true;
        });
        await _loadBackupHistory();
        _showSuccessMessage("Google Drive ile başarıyla bağlanıldı");
      } else {
        _showErrorMessage("Google Drive bağlantısı başarısız oldu");
      }
    } catch (e) {
      _showErrorMessage("Bağlantı hatası: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    setState(() => _isLoading = true);
    
    try {
      await _driveService.signOut();
      setState(() {
        _isAuthenticated = false;
        _backupHistory = [];
      });
      _showSuccessMessage("Google Drive bağlantısı kesildi");
    } catch (e) {
      _showErrorMessage("Çıkış yapılamadı: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _backupToDrive() async {
    if (!_isAuthenticated) {
      _showErrorMessage("Önce Google Drive'a bağlanmalısınız");
      return;
    }

    setState(() => _isLoading = true);
    
    try {
      final success = await _driveService.backupToDrive();
      if (success) {
        await _loadBackupHistory();
        _showSuccessMessage("Yedekleme başarıyla tamamlandı");
      } else {
        _showErrorMessage("Yedekleme başarısız oldu");
      }
    } catch (e) {
      _showErrorMessage("Yedekleme hatası: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _restoreFromDrive() async {
    if (!_isAuthenticated) {
      _showErrorMessage("Önce Google Drive'a bağlanmalısınız");
      return;
    }

    if (_backupHistory.isEmpty) {
      _showErrorMessage("Geri yüklenecek yedek bulunamadı");
      return;
    }

    // Onay dialogu göster
    final confirmed = await _showRestoreConfirmation();
    if (!confirmed) return;

    setState(() => _isLoading = true);
    
    try {
      final success = await _driveService.restoreFromDrive();
      if (success) {
        await _loadNoteCount();
        _showSuccessMessage("Yedekten geri yükleme başarıyla tamamlandı");
      } else {
        _showErrorMessage("Geri yükleme başarısız oldu");
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
            const Text('Yedekten geri yükleme işlemi mevcut notlarınızın üzerine yazabilir.'),
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
          ],
        ),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error, color: Colors.white),
            const SizedBox(width: 8),
            Text(message),
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
                              Icon(
                                _isAuthenticated ? Icons.cloud_done : Icons.cloud_off,
                                color: _isAuthenticated ? Colors.green : Colors.grey,
                                size: 32,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _isAuthenticated ? 'Google Drive Bağlı' : 'Google Drive Bağlı Değil',
                                      style: Theme.of(context).textTheme.titleLarge,
                                    ),
                                    Text(
                                      'Toplam Not: $_totalNotes',
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
                              if (!_isAuthenticated)
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _authenticate,
                                    icon: const Icon(Icons.login),
                                    label: const Text('Google Drive Bağlan'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.blue,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              if (_isAuthenticated) ...[
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _signOut,
                                    icon: const Icon(Icons.logout),
                                    label: const Text('Bağlantıyı Kes'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.grey,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ElevatedButton.icon(
                                    onPressed: _backupToDrive,
                                    icon: const Icon(Icons.cloud_upload),
                                    label: const Text('Yedekle'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.green,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Yedekleme Geçmişi
                  if (_isAuthenticated) ...[
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Yedekleme Geçmişi',
                                  style: Theme.of(context).textTheme.titleLarge,
                                ),
                                if (_backupHistory.isNotEmpty)
                                  ElevatedButton.icon(
                                    onPressed: _restoreFromDrive,
                                    icon: const Icon(Icons.cloud_download),
                                    label: const Text('Geri Yükle'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.orange,
                                      foregroundColor: Colors.white,
                                    ),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (_backupHistory.isEmpty)
                              const Text('Henüz yedekleme yapılmamış')
                            else
                              ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _backupHistory.length,
                                itemBuilder: (context, index) {
                                  final backup = _backupHistory[index];
                                  return ListTile(
                                    leading: const Icon(Icons.backup),
                                    title: Text(backup['name']),
                                    subtitle: Text(
                                      backup['createdTime']?.toString() ?? 'Bilinmeyen Tarih',
                                    ),
                                    trailing: Text(
                                      '${(backup['size'] ?? 0) / 1024} KB',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  );
                                },
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  
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
                          const Text('• Tüm notlarınız şifrelenerek Google Drive\'a yüklenir'),
                          const Text('• Yedekleriniz sadece sizin erişebileceğiniz özel klasörde saklanır'),
                          const Text('• İstediğiniz zaman yedeklerinizi geri yükleyebilirsiniz'),
                          const Text('• Şifreleme anahtarları cihazınızda güvenli saklanır'),
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
