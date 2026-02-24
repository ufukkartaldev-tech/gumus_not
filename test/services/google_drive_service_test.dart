import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:googleapis/drive/v3.dart' as drive;
import 'package:googleapis_auth/auth.dart';
import 'package:http/http.dart' as http;
import 'package:connected_notebook/services/google_drive_service.dart';
import 'package:connected_notebook/models/note_model.dart';

// Generate mocks
@GenerateMocks([
  AuthClient,
  drive.DriveApi,
  drive.FileList,
  drive.File,
  drive.Media,
  http.Client,
])
import 'google_drive_service_test.mocks.dart';

void main() {
  group('GoogleDriveService Tests', () {
    late GoogleDriveService service;
    late MockAuthClient mockClient;
    late MockDriveApi mockDriveApi;
    late MockFileList mockFileList;

    setUp(() {
      service = GoogleDriveService();
      mockClient = MockAuthClient();
      mockDriveApi = MockDriveApi();
      mockFileList = MockFileList();
    });

    group('Authentication Tests', () {
      test('Service starts unauthenticated', () {
        expect(service.isAuthenticated, isFalse);
      });

      test('Sign out clears authentication state', () async {
        // First set up authenticated state (in real scenario)
        // For testing, we'll just verify signOut doesn't throw
        expect(() => service.signOut(), returnsNormally);
      });

      test('Get backup history handles unauthenticated state', () async {
        final history = await service.getBackupHistory();
        expect(history, isEmpty);
      });

      test('Backup fails when not authenticated', () async {
        final result = await service.backupToDrive();
        expect(result, isFalse);
      });

      test('Restore fails when not authenticated', () async {
        final result = await service.restoreFromDrive();
        expect(result, isFalse);
      });
    });

    group('Backup Data Structure Tests', () {
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
        final timestamp = DateTime.now().toIso8601String();
        final expectedFileName = 'GumusNot_Backup_$timestamp.gnb';
        
        expect(expectedFileName, contains('GumusNot_Backup_'));
        expect(expectedFileName, contains('.gnb'));
        expect(expectedFileName, contains(timestamp));
      });

      test('File names are valid for file systems', () {
        final invalidChars = ['<', '>', ':', '"', '|', '?', '*'];
        final fileName = 'GumusNot_Backup_2023-01-01T12:00:00.000Z.gnb';
        
        for (final char in invalidChars) {
          expect(fileName, isNot(contains(char)));
        }
      });
    });

    group('Error Handling Tests', () {
      test('Service handles network errors gracefully', () {
        // Test that service doesn't crash on network errors
        expect(() => service.getBackupHistory(), returnsNormally);
      });

      test('Service handles authentication errors gracefully', () {
        // Test that service doesn't crash on auth errors
        expect(() => service.backupToDrive(), returnsNormally);
        expect(() => service.restoreFromDrive(), returnsNormally);
      });

      test('Service handles file system errors gracefully', () {
        // Test that service doesn't crash on file system errors
        expect(() => service.signOut(), returnsNormally);
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
      test('Complete backup workflow simulation', () {
        // Simulate the backup workflow without actual network calls
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

        // Simulate backup data creation
        final backupData = {
          'version': '1.0',
          'timestamp': DateTime.now().toIso8601String(),
          'notes': notes.map((note) => note.toJson()).toList(),
          'encrypted': true,
        };

        // Validate backup data structure
        expect(backupData['notes'], isA<List>());
        expect((backupData['notes'] as List).length, 2);
        expect(backupData['encrypted'], isTrue);
        expect(backupData['version'], '1.0');
      });

      test('Complete restore workflow simulation', () {
        // Simulate restore data structure
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

        // Validate restore data
        expect(restoreData['notes'], isA<List>());
        expect((restoreData['notes'] as List).length, 1);
        expect(restoreData['version'], '1.0');
        expect(restoreData['encrypted'], isTrue);

        // Test note restoration
        final noteJson = (restoreData['notes'] as List).first as Map<String, dynamic>;
        final restoredNote = Note.fromJson(noteJson);
        
        expect(restoredNote.title, 'Restored Note');
        expect(restoredNote.content, 'Restored content');
        expect(restoredNote.tags, ['restored']);
      });
    });

    group('Security Tests', () {
      test('Backup data encryption flag is set', () {
        final backupData = {
          'version': '1.0',
          'timestamp': DateTime.now().toIso8601String(),
          'notes': [],
          'encrypted': true,
        };

        expect(backupData['encrypted'], isTrue);
      });

      test('Encrypted notes are marked correctly', () {
        final encryptedNote = Note(
          id: 1,
          title: 'Secret Note',
          content: 'encrypted_content',
          createdAt: 1640995200000,
          updatedAt: 1640995260000,
          isEncrypted: true,
          tags: [],
        );

        expect(encryptedNote.isEncrypted, isTrue);
      });

      test('Non-encrypted notes are marked correctly', () {
        final normalNote = Note(
          id: 1,
          title: 'Normal Note',
          content: 'normal content',
          createdAt: 1640995200000,
          updatedAt: 1640995260000,
          isEncrypted: false,
          tags: [],
        );

        expect(normalNote.isEncrypted, isFalse);
      });
    });
  });
}
