import 'package:flutter_test/flutter_test.dart';
import 'package:connected_notebook/core/security/note_encryption_service.dart';

void main() {
  // Fixed 256-bit test key (base64), so every test uses the same vault key.
  const testKeyBase64 = '3q2+7wAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA=';

  NoteEncryptionService serviceWith(Future<String?> Function(String) reader) {
    return NoteEncryptionService(
      keyReader: reader,
      keyWriter: (key, value) async {},
    );
  }

  group('NoteEncryptionService', () {
    test('roundtrips unicode content', () async {
      final service = serviceWith((_) async => testKeyBase64);
      const plaintext = 'Gizli not: şifre 🔐 & <html> $ özel';

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
  });
}
