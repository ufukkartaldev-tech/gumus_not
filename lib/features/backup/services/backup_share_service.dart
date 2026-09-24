import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import 'package:connected_notebook/features/notes/models/note_model.dart';
import 'package:connected_notebook/features/notes/providers/note_provider.dart';

class BackupShareService {
  static final BackupShareService _instance = BackupShareService._internal();
  factory BackupShareService() => _instance;
  BackupShareService._internal();

  /// Export notes in plain text.
  Future<bool> exportAndShareBackup(BuildContext context) async {
    try {
      final noteProvider = context.read<NoteProvider>();

      await noteProvider.loadNotes();
      final notes = noteProvider.notes;
      if (notes.isEmpty) return false;

      final backupData = {
        'version': '2.0',
        'timestamp': DateTime.now().toIso8601String(),
        'notes': notes.map((note) => note.toJson()).toList(),
        'encrypted': false,
      };

      final dataStr = json.encode(backupData);
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final fileName = 'gumusnot_backup_$timestamp.json';

      if (kIsWeb) {
        final bytes = utf8.encode(dataStr);
        final xFile = XFile.fromData(Uint8List.fromList(bytes), name: fileName, mimeType: 'application/json');
        await xFile.saveTo(fileName);
      } else {
        final tempDir = await getTemporaryDirectory();
        final backupFile = File('${tempDir.path}/$fileName');
        await backupFile.writeAsString(dataStr);

        await Share.shareXFiles(
          [XFile(backupFile.path)],
          text: 'GümüşNot Yedek Dosyası',
        );
      }

      return true;
    } catch (e) {
      debugPrint('Yedekleme ve paylaşma hatası: $e');
      return false;
    }
  }

  /// Import plain text backup.
  Future<Map<String, dynamic>> importAndRestoreBackup(BuildContext context) async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.any);
      if (result == null) {
        return {'success': false, 'message': 'Dosya seçimi iptal edildi.'};
      }

      final noteProvider = context.read<NoteProvider>();
      String content = '';
      
      if (kIsWeb) {
        if (result.files.single.bytes == null) {
          return {'success': false, 'message': 'Dosya okunamadı.'};
        }
        content = utf8.decode(result.files.single.bytes!);
      } else {
        if (result.files.single.path == null) {
          return {'success': false, 'message': 'Dosya yolu bulunamadı.'};
        }
        final file = File(result.files.single.path!);
        content = await file.readAsString();
      }

      final backupData = json.decode(content) as Map<String, dynamic>;

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
      return {'success': false, 'message': 'Dosya bozuk olabilir: $e'};
    }
  }
}
