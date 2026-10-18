import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:connected_notebook/core/security/note_encryption_service.dart';

void main() {
  // Fixed 256-bit test key (base64), so every test uses the same vault key.
  const testKeyBase64 = '3q2+7wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';
  late Directory tempVaultDir;

  setUp(() async {
    tempVaultDir = await Directory.systemTemp.createTemp('gumusnot_vault_test');
  });

  tearDown(() async {
    if (tempVaultDir.existsSync()) {
      await tempVaultDir.delete(recursive: true);
    }
  });

  NoteEncryptionService serviceWith(Future<String?> Function(String) reader) {
    return NoteEncryptionService(
      keyReader: reader,
      keyWriter: (key, value) async {},
      vaultDirResolver: () async => tempVaultDir,
      pbkdf2Iterations: 1000,
    );
  }

  group('NoteEncryptionService (AES-256-GCM & Envelope Encryption)', () {
    test('roundtrips unicode content', () async {
      final service = serviceWith((_) async => testKeyBase64);
      const plaintext = r'Gizli not: şifre 🔐 & <html> $ özel';

      final payload = await service.encrypt(plaintext);

      expect(NoteEncryptionService.isEncryptedPayload(payload), isTrue);
      expect(await service.decrypt(payload), plaintext);
    });

    test('payload carries versioned prefix, iv and ciphertext', () async {
      final service = serviceWith((_) async => testKeyBase64);

      final payload = await service.encrypt('body');

      expect(payload.startsWith('enc:v1:'), isTrue);
      expect(payload.split(':').length, 4);
      expect(payload.contains('body'), isFalse);
    });

    test('decrypt fails with a different vault key', () async {
      final encrypter = serviceWith((_) async => testKeyBase64);
      final wrongKeyService = serviceWith(
        (_) async => 'MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=',
      );

      final payload = await encrypter.encrypt('secret');

      expect(
        () => wrongKeyService.decrypt(payload),
        throwsA(isA<NoteDecryptionException>()),
      );
    });

    test('decrypt fails on non-payload and malformed input', () async {
      final service = serviceWith((_) async => testKeyBase64);

      expect(
        () => service.decrypt('plain markdown'),
        throwsA(isA<NoteDecryptionException>()),
      );
      expect(
        () => service.decrypt('enc:v1:notbase64!!:alsobad!!'),
        throwsA(isA<NoteDecryptionException>()),
      );
    });

    test('generates and persists a key on first use, reuses it after', () async {
      final storage = <String, String>{};
      var reads = 0;
      final service = NoteEncryptionService(
        keyReader: (key) async {
          reads++;
          return storage[key];
        },
        keyWriter: (key, value) async => storage[key] = value,
        vaultDirResolver: () async => tempVaultDir,
        pbkdf2Iterations: 1000,
      );

      await service.encrypt('first');
      expect(storage, contains('note_vault_key'));
      expect(reads, 1);

      // A second encryption on the same instance must not re-read or
      // regenerate the key.
      await service.encrypt('second');
      expect(reads, 1);
      expect(storage.length, 1);
    });

    test('envelope encryption wraps DEK in .vault_key.json and recovers on a new device', () async {
      final device1Storage = <String, String>{};
      final device1 = NoteEncryptionService(
        keyReader: (k) async => device1Storage[k],
        keyWriter: (k, v) async => device1Storage[k] = v,
        vaultDirResolver: () async => tempVaultDir,
        pbkdf2Iterations: 2000,
      );

      await device1.setupMasterPassword('GucluParola123!');
      expect(await device1.hasEnvelope(), isTrue);

      final envelopeFile = File(p.join(tempVaultDir.path, '.vault_key.json'));
      final envelopeJson =
          jsonDecode(envelopeFile.readAsStringSync()) as Map<String, dynamic>;
      expect(envelopeJson['kdf'], 'PBKDF2-HMAC-SHA256');
      expect(envelopeJson['cipher'], 'AES-256-GCM');
      expect(envelopeJson['iterations'], 2000);
      expect(envelopeJson['salt'], isNotNull);
      expect(envelopeJson['iv'], isNotNull);
      expect(envelopeJson['ciphertext'], isNotNull);

      final payload = await device1.encrypt('Cihazlar arası gizli not');

      // Device 2: empty local secure storage, shares only the notes folder (.vault_key.json).
      final device2Storage = <String, String>{};
      final device2 = NoteEncryptionService(
        keyReader: (k) async => device2Storage[k],
        keyWriter: (k, v) async => device2Storage[k] = v,
        vaultDirResolver: () async => tempVaultDir,
        pbkdf2Iterations: 2000,
      );

      // Before unlocking with password, device2 must refuse to generate a conflicting key.
      expect(
        () => device2.decrypt(payload),
        throwsA(isA<VaultLockedByPasswordException>()),
      );

      // Wrong password must fail AES-GCM auth tag verification immediately.
      expect(
        () => device2.unlockWithMasterPassword('YanlisParola'),
        throwsA(isA<InvalidVaultPasswordException>()),
      );
      expect(device2Storage, isEmpty);

      // Correct password unwraps DEK, saves to device2 secure storage, and decrypts the note.
      await device2.unlockWithMasterPassword('GucluParola123!');
      expect(device2Storage['note_vault_key'], device1Storage['note_vault_key']);
      expect(await device2.decrypt(payload), 'Cihazlar arası gizli not');
    });

    test('changing master password re-wraps DEK without re-encrypting notes', () async {
      final storage = <String, String>{};
      final service = NoteEncryptionService(
        keyReader: (k) async => storage[k],
        keyWriter: (k, v) async => storage[k] = v,
        vaultDirResolver: () async => tempVaultDir,
        pbkdf2Iterations: 1500,
      );

      await service.setupMasterPassword('EskiParola123');
      final payload = await service.encrypt('Sabit DEK ile şifrelenmiş veri');

      await service.changeMasterPassword(
        currentPassword: 'EskiParola123',
        newPassword: 'YeniParola456',
      );

      // Old password must no longer work.
      final freshDevice = NoteEncryptionService(
        keyReader: (_) async => null,
        keyWriter: (k, v) async {},
        vaultDirResolver: () async => tempVaultDir,
        pbkdf2Iterations: 1500,
      );
      expect(
        () => freshDevice.unlockWithMasterPassword('EskiParola123'),
        throwsA(isA<InvalidVaultPasswordException>()),
      );

      // New password unwraps the exact same DEK and decrypts the existing note.
      await freshDevice.unlockWithMasterPassword('YeniParola456');
      expect(await freshDevice.decrypt(payload), 'Sabit DEK ile şifrelenmiş veri');
    });
  });
}
