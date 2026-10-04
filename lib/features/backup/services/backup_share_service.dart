import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import 'package:archive/archive_io.dart';

class BackupShareService {
  static final BackupShareService _instance = BackupShareService._internal();
  factory BackupShareService() => _instance;
  BackupShareService._internal();

  static const String _dbName = 'connected_notebook.db';

  /// Export database as a ZIP archive.
  Future<bool> exportAndShareBackup(BuildContext context) async {
    try {
      if (kIsWeb) {
        debugPrint('Web does not support direct SQLite export.');
        return false; 
      }

      final dbPath = p.join(await getDatabasesPath(), _dbName);
      final dbFile = File(dbPath);

      if (!await dbFile.exists()) {
        debugPrint('Veritabanı dosyası bulunamadı.');
        return false;
      }

      final dbBytes = await dbFile.readAsBytes();
      final archive = Archive();
      archive.addFile(ArchiveFile(_dbName, dbBytes.length, dbBytes));

      final zipData = ZipEncoder().encode(archive);
      if (zipData == null) return false;

      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'gumusnot_yedek_$timestamp.zip';
      final backupFile = File('${tempDir.path}/$fileName');
      
      await backupFile.writeAsBytes(zipData);

      await Share.shareXFiles(
        [XFile(backupFile.path, mimeType: 'application/zip')],
        text: 'GümüşNot Veritabanı Yedeği',
      );

      return true;
    } catch (e) {
      debugPrint('Yedekleme hatası: $e');
      return false;
    }
  }

  /// Import database from a ZIP archive.
  Future<Map<String, dynamic>> importAndRestoreBackup(BuildContext context) async {
    try {
      if (kIsWeb) return {'success': false, 'message': 'Web desteklenmiyor.'};

      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['zip'],
      );

      if (result == null || result.files.single.path == null) {
        return {'success': false, 'message': 'Dosya seçimi iptal edildi.'};
      }

      final zipBytes = await File(result.files.single.path!).readAsBytes();
      final archive = ZipDecoder().decodeBytes(zipBytes);

      ArchiveFile? dbArchiveFile;
      for (final file in archive) {
        if (file.name == _dbName) {
          dbArchiveFile = file;
          break;
        }
      }

      if (dbArchiveFile == null) {
        return {'success': false, 'message': 'Geçerli bir yedek dosyası bulunamadı.'};
      }

      final dbPath = p.join(await getDatabasesPath(), _dbName);
      final newDbBytes = dbArchiveFile.content as List<int>;
      
      await File(dbPath).writeAsBytes(newDbBytes, flush: true);

      return {
        'success': true,
        'message': 'Yedek başarıyla geri yüklendi. Etkili olması için uygulamayı yeniden başlatın.',
        'count': 1,
      };
    } catch (e) {
      debugPrint('Geri yükleme hatası: $e');
      return {'success': false, 'message': 'Dosya bozuk olabilir: $e'};
    }
  }
}
