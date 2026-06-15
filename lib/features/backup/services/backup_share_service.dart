import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';
import 'package:connected_notebook/features/notes/providers/vault_provider.dart';

class BackupShareService {
  static final BackupShareService _instance = BackupShareService._internal();
  factory BackupShareService() => _instance;
  BackupShareService._internal();

  /// Export notes using the active vault encryption flow.
  Future<bool> exportAndShareBackup(BuildContext context) async {
    try {
      final noteProvider = context.read<NoteProvider>();
      final vaultProvider = context.read<VaultProvider>();

      await noteProvider.loadNotes();
      final notes = noteProvider.notes;
      if (notes.isEmpty) return false;
      if (!vaultProvider.isUnlocked) {
        throw StateError('Yedek dışa aktarmak için önce kasayı açın.');
      }

      final backupData = {
        'version': '2.0',
        'timestamp': DateTime.now().toIso8601String(),
        'notes': notes.map((note) => note.toJson()).toList(),
        'encrypted': true,
      };

      final encryptedData = await context.read<VaultProvider>().resolveReadableBackupEnvelope(
            json.encode(backupData),
          );

      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final backupFile = File('${tempDir.path}/gumusnot_backup_$timestamp.gnb');
      await backupFile.writeAsString(encryptedData);

      await Share.shareXFiles(
        [XFile(backupFile.path)],
        text: 'GümüşNot Yedek Dosyası',
      );

      return true;
    } catch (e) {
      debugPrint('Yedekleme ve paylaşma hatası: $e');
      return false;
    }
  }

  /// Import backup using the active vault decryption flow.
  Future<Map<String, dynamic>> importAndRestoreBackup(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null || result.files.single.path == null) {
        return {'success': false, 'message': 'Dosya seçimi iptal edildi.'};
      }

      final vaultProvider = context.read<VaultProvider>();
      final noteProvider = context.read<NoteProvider>();
      if (!vaultProvider.isUnlocked) {
        return {'success': false, 'message': 'Yedek geri yüklemek için önce kasayı açın.'};
      }

      final file = File(result.files.single.path!);
      if (!file.path.endsWith('.gnb')) {
        return {'success': false, 'message': 'Lütfen geçerli bir .gnb yedek dosyası seçin.'};
      }

      final encryptedContent = await file.readAsString();
      final decryptedData = await vaultProvider.decryptExternalPayload(encryptedContent);
      final backupData = json.decode(decryptedData) as Map<String, dynamic>;

      final notes = (backupData['notes'] as List)
          .map((noteJson) => Note.fromJson(noteJson as Map<String, dynamic>))
          .toList();

      for (final note in notes) {
        if (note.id == null) {
          await noteProvider.addNote(note);
        } else {
          await noteProvider.updateNote(note);
        }
      }

      return {
        'success': true,
        'message': '${notes.length} not başarıyla geri yüklendi.',
        'count': notes.length,
      };
    } catch (e) {
      debugPrint('Geri yükleme hatası: $e');
      return {'success': false, 'message': 'Dosya bozuk olabilir veya çözme hatası: $e'};
    }
  }
}
