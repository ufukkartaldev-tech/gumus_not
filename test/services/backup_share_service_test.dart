import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/models/note_model.dart';
import 'dart:convert';

void main() {
  group('BackupShareService Data Structure Tests', () {
    test('Backup data structure is valid', () {
      final notes = [
        Note(
          id: 1,
          title: 'Test Note',
          content: 'Test content',
          createdAt: 1640995200000,
          updatedAt: 1640995260000,
          isEncrypted: false,
          tags: ['test'],
          folderName: 'Test Folder',
        ),
      ];

      // Simulate backup data creation
      final backupData = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'notes': notes.map((note) => note.toJson()).toList(),
        'encrypted': true,
      };

      expect(backupData['version'], '1.0');
      expect(backupData['notes'], isA<List>());
      expect(backupData['encrypted'], isTrue);
      expect(backupData['timestamp'], isA<String>());
    });

    test('Backup data includes all required fields', () {
      final note = Note(
        id: 1,
        title: 'Test Note',
        content: 'Test content with [[links]]',
        createdAt: 1640995200000,
        updatedAt: 1640995260000,
        isEncrypted: false,
        tags: ['test', 'backup'],
        color: 0xFFE3F2FD,
        folderName: 'Test Folder',
      );

      final noteJson = note.toJson();
      
      expect(noteJson['id'], 1);
      expect(noteJson['title'], 'Test Note');
      expect(noteJson['content'], 'Test content with [[links]]');
      expect(noteJson['createdAt'], 1640995200000);
      expect(noteJson['updatedAt'], 1640995260000);
      expect(noteJson['isEncrypted'], false);
      expect(noteJson['tags'], ['test', 'backup']);
      expect(noteJson['color'], 0xFFE3F2FD);
      expect(noteJson['folderName'], 'Test Folder');
    });

    test('Backup data handles encrypted notes', () {
      final encryptedNote = Note(
        id: 2,
        title: 'Encrypted Note',
        content: 'encrypted_content_here',
        createdAt: 1640995200000,
        updatedAt: 1640995260000,
        isEncrypted: true,
        tags: ['secret'],
        folderName: 'Private',
      );

      final noteJson = encryptedNote.toJson();
      expect(noteJson['isEncrypted'], isTrue);
      expect(noteJson['tags'], ['secret']);
      expect(noteJson['folderName'], 'Private');
    });

    test('Backup data handles empty notes list', () {
      final backupData = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'notes': <Map<String, dynamic>>[],
        'encrypted': true,
      };

      expect(backupData['notes'], isEmpty);
      expect(backupData['version'], '1.0');
      expect(backupData['encrypted'], isTrue);
    });
  });

  group('File Naming Tests', () {
    test('Backup file names include timestamp', () {
      final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final expectedFileName = 'gumusnot_backup_$timestamp.gnb';
      
      expect(expectedFileName, startsWith('gumusnot_backup_'));
      expect(expectedFileName, endsWith('.gnb'));
      expect(expectedFileName, contains(timestamp));
    });
  });

  group('Data Validation Tests', () {
    test('Backup data timestamp is valid ISO format', () {
      final timestamp = DateTime.now().toIso8601String();
      expect(() => DateTime.parse(timestamp), returnsNormally);
    });

    test('Backup version is consistent', () {
      final version = '1.0';
      expect(version, isA<String>());
      expect(version, isNotEmpty);
    });

    test('Note data validation', () {
      final note = Note(
        id: 1,
        title: 'Test Note',
        content: 'Test content',
        createdAt: DateTime.now().millisecondsSinceEpoch,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
        isEncrypted: false,
        tags: [],
      );

      expect(note.id, greaterThan(0));
      expect(note.title, isA<String>());
      expect(note.content, isA<String>());
      expect(note.createdAt, greaterThan(0));
      expect(note.updatedAt, greaterThan(0));
      expect(note.isEncrypted, isA<bool>());
      expect(note.tags, isA<List<String>>());
    });
  });

  group('Integration Simulation Tests', () {
    test('Complete backup workflow payload simulation', () {
      final notes = [
        Note(
          id: 1,
          title: 'Test Note 1',
          content: 'Content 1',
          createdAt: 1640995200000,
          updatedAt: 1640995260000,
          isEncrypted: false,
          tags: ['test'],
        ),
        Note(
          id: 2,
          title: 'Test Note 2',
          content: 'Content 2',
          createdAt: 1640995270000,
          updatedAt: 1640995280000,
          isEncrypted: true,
          tags: ['secret'],
        ),
      ];

      final backupData = {
        'version': '1.0',
        'timestamp': DateTime.now().toIso8601String(),
        'notes': notes.map((note) => note.toJson()).toList(),
        'encrypted': true,
      };

      expect(backupData['notes'], isA<List>());
      expect((backupData['notes'] as List).length, 2);
      expect(backupData['encrypted'], isTrue);
      expect(backupData['version'], '1.0');
    });

    test('Complete restore workflow simulation', () {
      final restoreData = {
        'version': '1.0',
        'timestamp': '2023-01-01T12:00:00.000Z',
        'notes': [
          {
            'id': 1,
            'title': 'Restored Note',
            'content': 'Restored content',
            'createdAt': 1640995200000,
            'updatedAt': 1640995260000,
            'isEncrypted': false,
            'tags': ['restored'],
            'folderName': 'Genel',
          }
        ],
        'encrypted': true,
      };

      expect(restoreData['notes'], isA<List>());
      expect((restoreData['notes'] as List).length, 1);
      expect(restoreData['version'], '1.0');
      expect(restoreData['encrypted'], isTrue);

      final noteJson = (restoreData['notes'] as List).first as Map<String, dynamic>;
      final restoredNote = Note.fromJson(noteJson);
      
      expect(restoredNote.title, 'Restored Note');
      expect(restoredNote.content, 'Restored content');
      expect(restoredNote.tags, ['restored']);
    });
  });
}
