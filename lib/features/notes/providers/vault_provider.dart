import 'package:flutter/foundation.dart';

import '../../../core/security/legacy_encryption_service_adapter.dart';
import '../../../core/security/vault_service_v2.dart';
import '../models/note_model.dart';
import '../services/note_service.dart';

/// UI-facing view model for vault state, on-demand decryption and secure note
/// create/update flows.
class VaultProvider with ChangeNotifier {
  VaultProvider({
    required LegacyEncryptionServiceAdapter encryptionAdapter,
    required IVaultServiceV2 vaultService,
    required NoteService noteService,
  })  : _encryptionAdapter = encryptionAdapter,
        _vaultService = vaultService,
        _noteService = noteService;

  final LegacyEncryptionServiceAdapter _encryptionAdapter;
  final IVaultServiceV2 _vaultService;
  final NoteService _noteService;

  bool _isUnlocked = false;
  bool _isBusy = false;
  String? _errorMessage;
  final Map<int, String> _resolvedContentCache = {};

  bool get isUnlocked => _isUnlocked;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  /// Initialize local UI state from the vault service.
  void syncState() {
    _isUnlocked = _vaultService.isUnlocked;
    notifyListeners();
  }

  Future<bool> unlockWithPassword(String password) async {
    return _runBusy(() async {
      final unlocked = await _encryptionAdapter.unlockWithPassword(password);
      _isUnlocked = unlocked;
      if (!unlocked) {
        _errorMessage = 'Kasa şifresi doğrulanamadı.';
      }
      return unlocked;
    });
  }

  Future<void> initializeVault({
    required String password,
    String? recoveryKey,
  }) async {
    await _runBusy(() async {
      await _encryptionAdapter.initializeVault(
        password: password,
        recoveryKey: recoveryKey,
      );
      _isUnlocked = true;
      _errorMessage = null;
    });
  }

  Future<bool> unlockWithRecoveryKey(String recoveryKey) async {
    return _runBusy(() async {
      final unlocked = await _encryptionAdapter.initializeWithRecoveryKey(recoveryKey);
      _isUnlocked = unlocked;
      if (!unlocked) {
        _errorMessage = 'Kurtarma anahtarı doğrulanamadı.';
      }
      return unlocked;
    });
  }

  Future<void> lockVault() async {
    await _runBusy(() async {
      await _vaultService.lock();
      _resolvedContentCache.clear();
      _isUnlocked = false;
      _errorMessage = null;
    });
  }

  /// Decrypt a note only when explicitly requested by a detail/private-note view.
  Future<String> resolveReadableContent(Note note) async {
    if (!note.isEncrypted) {
      return note.content;
    }

    final noteId = note.id;
    if (noteId != null && _resolvedContentCache.containsKey(noteId)) {
      return _resolvedContentCache[noteId]!;
    }

    final resolved = await _runBusy(() => _noteService.resolveReadableContent(note));
    if (noteId != null) {
      _resolvedContentCache[noteId] = resolved;
    }
    return resolved;
  }

  Future<Note> createPrivateNote({
    required String title,
    required String content,
    List<String> tags = const ['özel'],
    String folderName = 'Genel',
    int? color,
  }) async {
    return _runBusy(() async {
      final note = await _noteService.createNote(
        title: title,
        content: content,
        tags: tags,
        folderName: folderName,
        color: color,
        isEncrypted: true,
      );

      if (note.id != null) {
        _resolvedContentCache[note.id!] = content;
      }

      return note;
    });
  }

  Future<Note> updatePrivateNote({
    required Note note,
    required String plainTextContent,
  }) async {
    return _runBusy(() async {
      final updated = await _noteService.updateNote(
        note.copyWith(
          content: plainTextContent,
          isEncrypted: true,
        ),
      );

      if (updated.id != null) {
        _resolvedContentCache[updated.id!] = plainTextContent;
      }

      return updated;
    });
  }

  Future<String> resolveReadableBackupEnvelope(String plainText) async {
    return _runBusy(() async {
      if (!_isUnlocked) {
        throw StateError('Vault is locked.');
      }
      return _encryptionAdapter.encrypt(plainText);
    });
  }

  Future<String> decryptExternalPayload(String encryptedPayload) async {
    return _runBusy(() async {
      if (!_isUnlocked) {
        throw StateError('Vault is locked.');
      }
      return _encryptionAdapter.decrypt(encryptedPayload);
    });
  }

  Future<T> _runBusy<T>(Future<T> Function() operation) async {
    _isBusy = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final result = await operation();
      _errorMessage = null;
      return result;
    } catch (e) {
      _errorMessage = e.toString();
      rethrow;
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
