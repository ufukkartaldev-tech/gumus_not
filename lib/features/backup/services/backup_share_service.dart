import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:connected_notebook/features/backup/services/markdown_backup_utils.dart';

class BackupShareService {
  static final BackupShareService _instance = BackupShareService._internal();
  factory BackupShareService() => _instance;
  BackupShareService._internal();

  bool get isDesktop =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux ||
          defaultTargetPlatform == TargetPlatform.macOS);

  String _formatTimestamp(DateTime now) {
    return '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}_'
        '${now.hour.toString().padLeft(2, '0')}${now.minute.toString().padLeft(2, '0')}';
  }

  /// Exports an encrypted local backup (.enc) protected with AES-256-GCM and PBKDF2.
  /// On Desktop (Windows/Linux/macOS), displays a native File Save Dialog.
  /// On Mobile, displays the system share sheet.
  Future<Map<String, dynamic>> exportEncryptedBackup(
    BuildContext context, {
    required String password,
    Directory? root,
  }) async {
    try {
      if (kIsWeb) {
        return {'success': false, 'message': 'Web platformu dosya yedeğini desteklemiyor.'};
      }

      final encBytes = await MarkdownBackupUtils.createEncryptedBackup(
        password: password,
        root: root,
      );

      if (encBytes == null || encBytes.isEmpty) {
        return {'success': false, 'message': 'Yedeklenecek not veya şablon bulunamadı.'};
      }

      final fileName = 'GumusNot_Yedek_${_formatTimestamp(DateTime.now())}.enc';

      if (isDesktop) {
        final savePath = await FilePicker.platform.saveFile(
          dialogTitle: 'Şifreli GümüşNot Yedeğini Kaydet (.enc)',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['enc'],
        );

        if (savePath == null) {
          return {'success': false, 'cancelled': true, 'message': 'Yedekleme iptal edildi.'};
        }

        final effectivePath = savePath.endsWith('.enc') ? savePath : '$savePath.enc';
        final file = File(effectivePath);
        await file.writeAsBytes(encBytes, flush: true);

        return {
          'success': true,
          'path': effectivePath,
          'message': 'Şifreli yedek başarıyla kaydedildi: $effectivePath',
        };
      } else {
        final tempDir = await getTemporaryDirectory();
        final backupFile = File('${tempDir.path}/$fileName');
        await backupFile.writeAsBytes(encBytes, flush: true);

        await Share.shareXFiles(
          [XFile(backupFile.path, mimeType: 'application/octet-stream')],
          text: 'GümüşNot Şifreli Yedek',
        );

        return {
          'success': true,
          'path': backupFile.path,
          'message': 'Şifreli yedekleme hazırlandı.',
        };
      }
    } catch (e) {
      debugPrint('Şifreli yedekleme hatası: $e');
      return {'success': false, 'message': 'Yedekleme başarısız oldu: $e'};
    }
  }

  /// Imports and restores an encrypted backup (.enc) with automatic safety rollback.
  Future<Map<String, dynamic>> importEncryptedBackup(
    BuildContext context, {
    required String password,
    String? preSelectedPath,
    Directory? root,
    bool replaceExisting = false,
  }) async {
    try {
      if (kIsWeb) {
        return {'success': false, 'message': 'Web platformu desteklenmiyor.'};
      }

      String? filePath = preSelectedPath;
      if (filePath == null) {
        final result = await FilePicker.platform.pickFiles(
          dialogTitle: 'Şifreli GümüşNot Yedeğini Seçin (.enc)',
          type: FileType.custom,
          allowedExtensions: ['enc'],
        );

        if (result == null || result.files.single.path == null) {
          return {'success': false, 'cancelled': true, 'message': 'Dosya seçimi iptal edildi.'};
        }
        filePath = result.files.single.path!;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        return {'success': false, 'message': 'Seçilen yedekleme dosyası bulunamadı.'};
      }

      final encBytes = await file.readAsBytes();
      final restoredCount = await MarkdownBackupUtils.restoreEncryptedBackup(
        encBytes,
        password,
        root: root,
        replaceExisting: replaceExisting,
      );

      return {
        'success': true,
        'count': restoredCount,
        'message': 'Şifreli yedek başarıyla geri yüklendi ($restoredCount dosya).',
      };
    } on InvalidBackupPasswordException catch (e) {
      return {'success': false, 'message': e.message};
    } on CorruptedBackupException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      debugPrint('Şifreli geri yükleme hatası: $e');
      return {'success': false, 'message': 'Geri yükleme başarısız oldu: $e'};
    }
  }

  /// Exports an unencrypted portable ZIP archive.
  Future<Map<String, dynamic>> exportZipArchive(
    BuildContext context, {
    Directory? root,
  }) async {
    try {
      if (kIsWeb) {
        return {'success': false, 'message': 'Web platformu dosya yedeğini desteklemiyor.'};
      }

      final zipBytes = await MarkdownBackupUtils.createZipBackup(root: root);
      if (zipBytes == null || zipBytes.isEmpty) {
        return {'success': false, 'message': 'Dışa aktarılacak not veya şablon bulunamadı.'};
      }

      final fileName = 'GumusNot_Arsiv_${_formatTimestamp(DateTime.now())}.zip';

      if (isDesktop) {
        final savePath = await FilePicker.platform.saveFile(
          dialogTitle: 'Taşınabilir Not Arşivini Kaydet (.zip)',
          fileName: fileName,
          type: FileType.custom,
          allowedExtensions: ['zip'],
        );

        if (savePath == null) {
          return {'success': false, 'cancelled': true, 'message': 'Dışa aktarma iptal edildi.'};
        }

        final effectivePath = savePath.endsWith('.zip') ? savePath : '$savePath.zip';
        final file = File(effectivePath);
        await file.writeAsBytes(zipBytes, flush: true);

        return {
          'success': true,
          'path': effectivePath,
          'message': 'Taşınabilir arşiv başarıyla kaydedildi: $effectivePath',
        };
      } else {
        final tempDir = await getTemporaryDirectory();
        final backupFile = File('${tempDir.path}/$fileName');
        await backupFile.writeAsBytes(zipBytes, flush: true);

        await Share.shareXFiles(
          [XFile(backupFile.path, mimeType: 'application/zip')],
          text: 'GümüşNot Not Arşivi (ZIP)',
        );

        return {
          'success': true,
          'path': backupFile.path,
          'message': 'Taşınabilir arşiv hazırlandı.',
        };
      }
    } catch (e) {
      debugPrint('ZIP dışa aktarma hatası: $e');
      return {'success': false, 'message': 'Dışa aktarma başarısız oldu: $e'};
    }
  }

  /// Imports and restores a portable ZIP archive with automatic safety rollback.
  Future<Map<String, dynamic>> importZipArchive(
    BuildContext context, {
    String? preSelectedPath,
    Directory? root,
    bool replaceExisting = false,
  }) async {
    try {
      if (kIsWeb) {
        return {'success': false, 'message': 'Web platformu desteklenmiyor.'};
      }

      String? filePath = preSelectedPath;
      if (filePath == null) {
        final result = await FilePicker.platform.pickFiles(
          dialogTitle: 'Taşınabilir Not Arşivini Seçin (.zip)',
          type: FileType.custom,
          allowedExtensions: ['zip'],
        );

        if (result == null || result.files.single.path == null) {
          return {'success': false, 'cancelled': true, 'message': 'Dosya seçimi iptal edildi.'};
        }
        filePath = result.files.single.path!;
      }

      final file = File(filePath);
      if (!await file.exists()) {
        return {'success': false, 'message': 'Seçilen arşiv dosyası bulunamadı.'};
      }

      final zipBytes = await file.readAsBytes();
      final restoredCount = await MarkdownBackupUtils.restoreZipBackup(
        zipBytes,
        root: root,
        replaceExisting: replaceExisting,
      );

      return {
        'success': true,
        'count': restoredCount,
        'message': 'ZIP arşivi başarıyla geri yüklendi ($restoredCount dosya).',
      };
    } on CorruptedBackupException catch (e) {
      return {'success': false, 'message': e.message};
    } catch (e) {
      debugPrint('ZIP geri yükleme hatası: $e');
      return {'success': false, 'message': 'Arşiv geri yüklenemedi: $e'};
    }
  }

  /// Backward compatible helper for legacy calls.
  Future<bool> exportAndShareBackup(BuildContext context) async {
    final result = await exportZipArchive(context);
    return result['success'] == true;
  }

  /// Backward compatible helper for legacy calls.
  Future<Map<String, dynamic>> importAndRestoreBackup(BuildContext context) async {
    return await importZipArchive(context, replaceExisting: true);
  }
}
