import 'dart:convert';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:file_picker/file_picker.dart';
import 'package:connected_notebook/core/database/database_service.dart';
import 'package:connected_notebook/core/security/encryption_service.dart';
import 'package:connected_notebook/features/notes/models/note_model.dart';

class BackupShareService {
  static final BackupShareService _instance = BackupShareService._internal();
  factory BackupShareService() => _instance;
  BackupShareService._internal();

  // Veritabanını şifrele ve temp klasörüne kaydedip paylaş
  Future<bool> exportAndShareBackup() async {
    try {
      // 1. Veritabanını al
      final notes = await DatabaseService.getAllNotes();
      if (notes.isEmpty) return false;

      final backupData = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'notes': notes.map((note) => note.toJson()).toList(),
        'encrypted': true,
      };

      // 2. Veriyi şifrele
      final encryptedData = EncryptionService.encrypt(json.encode(backupData));

      // 3. Geçici dosya oluştur
      final tempDir = await getTemporaryDirectory();
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final backupFile = File('${tempDir.path}/gumusnot_backup_$timestamp.gnb');
      
      await backupFile.writeAsString(encryptedData);

      // 4. Dosyayı paylaş
      final xFile = XFile(backupFile.path);
      await Share.shareXFiles(
        [xFile],
        text: 'GümüşNot Yedek Dosyası',
      );

      return true;
    } catch (e) {
      print("Yedekleme ve paylaşma hatası: $e");
      return false;
    }
  }

  // Kullanıcıdan dosya seçtir ve geri yükle
  Future<Map<String, dynamic>> importAndRestoreBackup() async {
    try {
      // 1. Dosya seçiciyi aç
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.any, // .gnb uzantısı Android/iOS'ta özel tanımlı olmayabilir
      );

      if (result == null || result.files.single.path == null) {
        return {'success': false, 'message': 'Dosya seçimi iptal edildi.'};
      }

      final file = File(result.files.single.path!);
      
      if (!file.path.endsWith('.gnb')) {
         return {'success': false, 'message': 'Lütfen geçerli bir .gnb yedek dosyası seçin.'};
      }

      // 2. Dosyayı oku ve şifreyi çöz
      final encryptedContent = await file.readAsString();
      final decryptedData = EncryptionService.decrypt(encryptedContent);
      
      final backupData = json.decode(decryptedData);
      
      // 3. Verileri dönüştür ve ekle
      final notes = (backupData['notes'] as List)
          .map((noteJson) => Note.fromJson(noteJson))
          .toList();
      
      int restoredCount = 0;
      for (final note in notes) {
        // İsteğe bağlı: Eklemeden önce aynı id'li not var mı kontrol edilebilir 
        // veya DatabaseService.insertNote içinde id yoksayılabilir (yeni id alır).
        // Şu anki yapıya göre ID manuel olarak çakışmayı önlemek için silinip yeniden atanabilir
        // veya üzerine yazılabilir. Direkt insert edelim.
        await DatabaseService.insertNote(note);
        restoredCount++;
      }

      return {
        'success': true, 
        'message': '$restoredCount not başarıyla geri yüklendi.',
        'count': restoredCount,
      };
    } catch (e) {
      print("Geri yükleme hatası: $e");
      return {'success': false, 'message': 'Dosya bozuk olabilir veya şifreleme/okuma hatası: $e'};
    }
  }
}
