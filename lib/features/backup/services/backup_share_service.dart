import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:archive/archive_io.dart';
import 'dart:io';

import 'package:connected_notebook/features/backup/services/markdown_backup_utils.dart';

class BackupShareService {
  static final BackupShareService _instance = BackupShareService._internal();
  factory BackupShareService() => _instance;
  BackupShareService._internal();

  /// Export the markdown workspace (notes + templates) as a ZIP archive.
  Future<bool> exportAndShareBackup(BuildContext context) async {
    try {
      if (kIsWeb) {
        debugPrint('Web does not support filesystem backup export.');
        return false;
      }

      final zipData = await MarkdownBackupUtils.zipWorkspace();
      if (zipData == null || zipData.isEmpty) {
        debugPrint('Yedeklenecek markdown dosyası bulunamadı.');
        return false;
      }

      final tempDir = await getTemporaryDirectory();
      final now = DateTime.now();
      final timestamp = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}';
      final fileName = 'gumusnot_yedek_$timestamp.zip';
      final backupFile = File('${tempDir.path}/$fileName');

      await backupFile.writeAsBytes(zipData);

      await Share.shareXFiles(
        [XFile(backupFile.path, mimeType: 'application/zip')],
        text: 'GümüşNot Not Yedeği',
      );

      return true;
    } catch (e) {
      debugPrint('Yedekleme hatası: $e');
      return false;
    }
  }

  /// Import a markdown workspace ZIP archive created by [exportAndShareBackup].
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

      final restoredCount = await MarkdownBackupUtils.extractWorkspace(archive);

      return {
        'success': true,
        'message': 'Yedek başarıyla geri yüklendi ($restoredCount dosya). Etkili olması için uygulamayı yeniden başlatın.',
        'count': restoredCount,
      };
    } catch (e) {
      debugPrint('Geri yükleme hatası: $e');
      return {'success': false, 'message': 'Dosya bozuk olabilir: $e'};
    }
  }
}
